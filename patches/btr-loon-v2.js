/*
 * Bilibili Thread Ripper for Loon
 * Version 2.0.0
 *
 * CDN Smart Scheduler
 * Success Rate
 * Latency Tracking
 * Failure Cooldown
 * Automatic Recovery
 */

(function () {
    "use strict";

    const VERSION = "2.0.0";
    const DB_KEY = "BTR_LOON_V2_HEALTH";

    const MAINLAND = [
        "upos-sz-mirrorali.bilivideo.com",
        "upos-sz-mirrorhw.bilivideo.com",
        "upos-sz-mirrorbos.bilivideo.com",
        "upos-sz-mirror08c.bilivideo.com",
        "upos-sz-mirrorbd.bilivideo.com",
        "upos-sz-mirror14b.bilivideo.com",
        "upos-sz-estgoss.bilivideo.com",
        "upos-sz-mirrorcos.bilivideo.com",
        "upos-sz-mirrorcoso1.bilivideo.com"
    ];

    const OVERSEAS = [
        "upos-sz-mirrorcosov.bilivideo.com",
        "upos-sz-mirroraliov.bilivideo.com",
        "cn-hk-eq-01-01.bilivideo.com",
        "cn-hk-eq-01-03.bilivideo.com"
    ];

    const arg = $argument || {};

    const enabled = arg.enabled !== false;

    if (!enabled) {
        $done({});
        return;
    }

    const region = arg.region || "mainland";
    const mode = arg.mode || "smart";
    const maxFail = Number(arg.maxFail || 3);
    const cooldown = Number(arg.cooldown || 300) * 1000;
    const debug = arg.debug === true;

    function log(message) {
        if (debug) {
            console.log("[BTR V2] " + message);
        }
    }

    function loadDB() {
        try {
            return JSON.parse(
                $persistentStore.read(DB_KEY) || "{}"
            );
        } catch (_) {
            return {};
        }
    }

    function saveDB(db) {
        $persistentStore.write(
            JSON.stringify(db),
            DB_KEY
        );
    }

    function getHosts() {
        return region === "overseas"
            ? OVERSEAS
            : MAINLAND;
    }

    function getHost(url) {
        try {
            return new URL(url).hostname.toLowerCase();
        } catch (_) {
            return "";
        }
    }

    function isValidMedia(url) {
        try {
            const u = new URL(url);

            const host = u.hostname.toLowerCase();

            const validDomain =
                /(?:^|\.)bilivideo\.(?:com|cn|net)$/.test(host);

            const validPath =
                /\.(m4s|mp4|flv)$/i.test(u.pathname);

            return validDomain && validPath;
        } catch (_) {
            return false;
        }
    }

    function isRelay(url) {
        try {
            const u = new URL(url);

            return (
                /(?:^|\.)mcdn\./i.test(u.hostname) ||
                /^\/v1\/resource\//i.test(u.pathname) ||
                (u.searchParams.get("os") || "").toLowerCase() === "mcdn"
            );
        } catch (_) {
            return true;
        }
    }

    function isAkamai(url) {
        return /\.akamaized\.net$/i.test(getHost(url));
    }

    function getState(db, host) {
        if (!db[host]) {
            db[host] = {
                success: 0,
                failure: 0,
                latency: 0,
                samples: 0,
                streak: 0,
                cooldownUntil: 0,
                lastUsed: 0
            };
        }

        return db[host];
    }

    function score(state) {
        const total = state.success + state.failure;

        const successRate = total
            ? state.success / total
            : 0.5;

        const latencyScore = state.samples
            ? 1000 / Math.max(1, state.latency)
            : 0.5;

        return (
            successRate * 0.6 +
            latencyScore * 0.4
        );
    }

    function available(host, state) {
        if (state.cooldownUntil > Date.now()) {
            return false;
        }

        return true;
    }

    function selectHost(hosts, db) {
        const now = Date.now();

        const candidates = hosts.map(host => ({
            host,
            state: getState(db, host)
        }));

        // 过期节点自动恢复
        candidates.forEach(item => {
            if (
                item.state.cooldownUntil &&
                item.state.cooldownUntil <= now
            ) {
                item.state.cooldownUntil = 0;
                item.state.streak = 0;
                log("节点恢复: " + item.host);
            }
        });

        let availableHosts = candidates.filter(item =>
            available(item.host, item.state)
        );

        if (!availableHosts.length) {
            availableHosts = candidates;
        }

        if (mode === "roundrobin") {
            availableHosts.sort(
                (a, b) =>
                    a.state.lastUsed - b.state.lastUsed
            );
        } else {
            availableHosts.sort(
                (a, b) =>
                    score(b.state) - score(a.state)
            );
        }

        const selected = availableHosts[0];

        selected.state.lastUsed = now;

        return selected.host;
    }

    function updateResult(host, status, elapsed, db) {
        const state = getState(db, host);

        if (status >= 200 && status < 400) {
            state.success++;
            state.streak = 0;

            if (elapsed > 0) {
                state.samples++;

                state.latency =
                    state.samples === 1
                        ? elapsed
                        : state.latency * 0.7 +
                          elapsed * 0.3;
            }

            state.cooldownUntil = 0;

            log(
                "成功 " + host +
                " HTTP " + status +
                " " + elapsed + "ms"
            );

        } else if (
            status === 403 ||
            status === 404 ||
            status >= 500
        ) {
            state.failure++;
            state.streak++;

            log(
                "失败 " + host +
                " HTTP " + status
            );

            if (state.streak >= maxFail) {
                state.cooldownUntil =
                    Date.now() + cooldown;

                state.streak = 0;

                log(
                    "节点进入冷却: " + host
                );
            }
        }

        saveDB(db);
    }

    function requestHandler() {
        const original = $request.url;

        if (
            !isValidMedia(original) ||
            isRelay(original) ||
            isAkamai(original)
        ) {
            $done({});
            return;
        }

        const originalHost = getHost(original);

        const hosts = getHosts();

        if (!hosts.length) {
            $done({});
            return;
        }

        const db = loadDB();

        const selected = selectHost(hosts, db);

        if (selected === originalHost) {
            $done({});
            return;
        }

        const url = new URL(original);

        // 仅替换 hostname，保留路径及全部签名参数
        url.hostname = selected;
        url.port = "";

        const newURL = url.toString();

        // 保存请求开始时间
        const key = "BTR_V2_TIME_" +
            encodeURIComponent(newURL);

        $persistentStore.write(
            String(Date.now()),
            key
        );

        log(
            originalHost + " -> " + selected
        );

        $done({
            url: newURL
        });
    }

    function responseHandler() {
        const url = $request.url;
        const host = getHost(url);

        const key = "BTR_V2_TIME_" +
            encodeURIComponent(url);

        const start = Number(
            $persistentStore.read(key) || 0
        );

        $persistentStore.write(undefined, key);

        const elapsed = start
            ? Date.now() - start
            : 0;

        const status = Number($response.status || 0);

        const db = loadDB();

        updateResult(
            host,
            status,
            elapsed,
            db
        );

        $done({});
    }

    try {
        const name = String(
            ($script && $script.name) || ""
        ).toLowerCase();

        if (name.includes("response")) {
            responseHandler();
        } else {
            requestHandler();
        }
    } catch (e) {
        log("异常: " + e);

        $done({});
    }

})();
