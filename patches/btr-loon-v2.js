/*
 * Bilibili Thread Ripper for Loon
 * Version: 2.1.0
 *
 * Smart CDN Scheduler
 * Request / Response Detection
 * Success Rate Statistics
 * Latency Tracking
 * Failure Cooldown
 * Automatic Recovery
 */

(function () {
    "use strict";

    const VERSION = "2.1.0";
    const DB_KEY = "BTR_LOON_V21_HEALTH";
    const TIME_KEY = "BTR_LOON_V21_TIMES";

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

    // -------------------------
    // 参数解析
    // -------------------------

    function parseArgument(input) {
        if (input && typeof input === "object") {
            return input;
        }

        const result = {};

        if (typeof input === "string") {
            input.split("&").forEach(function (item) {
                const index = item.indexOf("=");

                if (index < 0) return;

                const key = decodeURIComponent(
                    item.slice(0, index)
                );

                const value = decodeURIComponent(
                    item.slice(index + 1)
                );

                result[key] = value;
            });
        }

        return result;
    }

    const arg = parseArgument($argument);

    const enabled = arg.enabled !== false &&
        arg.enabled !== "false";

    if (!enabled) {
        $done({});
        return;
    }

    const region = arg.region || "mainland";
    const mode = arg.mode || "smart";

    const maxFail = Math.max(
        1,
        Number(arg.maxFail) || 3
    );

    const cooldown = Math.max(
        30,
        Number(arg.cooldown) || 300
    ) * 1000;

    const debug = arg.debug === true ||
        arg.debug === "true";

    // -------------------------
    // 日志
    // -------------------------

    function log(message) {
        if (debug) {
            console.log(
                "[BTR " + VERSION + "] " + message
            );
        }
    }

    // -------------------------
    // 持久化
    // -------------------------

    function loadJSON(key) {
        try {
            return JSON.parse(
                $persistentStore.read(key) || "{}"
            );
        } catch (_) {
            return {};
        }
    }

    function saveJSON(key, value) {
        $persistentStore.write(
            JSON.stringify(value),
            key
        );
    }

    // -------------------------
    // CDN
    // -------------------------

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

            const validDomain =
                /(?:^|\.)bilivideo\.(com|cn|net)$/i
                .test(u.hostname);

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
                (u.searchParams.get("os") || "")
                    .toLowerCase() === "mcdn"
            );

        } catch (_) {
            return true;
        }
    }

    // -------------------------
    // 节点状态
    // -------------------------

    function getState(db, host) {
        if (!db[host]) {
            db[host] = {
                success: 0,
                failure: 0,
                latency: 0,
                samples: 0,
                streak: 0,
                cooldownUntil: 0,
                lastUsed: 0,
                lastStatus: 0
            };
        }

        return db[host];
    }

    // -------------------------
    // CDN 评分
    // -------------------------

    function score(state) {
        const total =
            state.success + state.failure;

        const successRate = total > 0
            ? state.success / total
            : 0.5;

        const latencyScore = state.samples > 0
            ? 1000 / Math.max(1, state.latency)
            : 0.5;

        return (
            successRate * 0.6 +
            Math.min(1, latencyScore) * 0.4
        );
    }

    function selectHost(hosts, db) {
        const now = Date.now();

        const candidates = hosts.map(function (host) {
            return {
                host: host,
                state: getState(db, host)
            };
        });

        // 自动恢复
        candidates.forEach(function (item) {
            const state = item.state;

            if (
                state.cooldownUntil > 0 &&
                state.cooldownUntil <= now
            ) {
                state.cooldownUntil = 0;
                state.streak = 0;

                log("节点恢复: " + item.host);
            }
        });

        let available = candidates.filter(function (item) {
            return item.state.cooldownUntil <= now;
        });

        if (!available.length) {
            available = candidates;
        }

        if (mode === "roundrobin") {
            available.sort(function (a, b) {
                return a.state.lastUsed -
                    b.state.lastUsed;
            });

        } else {
            // 优先探索尚未使用过的节点
            const unexplored = available.filter(
                function (item) {
                    return (
                        item.state.success +
                        item.state.failure
                    ) === 0;
                }
            );

            if (unexplored.length > 0) {
                available = unexplored;
            } else {
                available.sort(function (a, b) {
                    const difference =
                        score(b.state) -
                        score(a.state);

                    if (Math.abs(difference) < 0.0001) {
                        return a.state.lastUsed -
                            b.state.lastUsed;
                    }

                    return difference;
                });
            }
        }

        const selected = available[0];

        selected.state.lastUsed = now;

        return selected.host;
    }

    // -------------------------
    // 请求时间队列
    // -------------------------

    function recordStart(url) {
        const times = loadJSON(TIME_KEY);

        if (!Array.isArray(times[url])) {
            times[url] = [];
        }

        times[url].push(Date.now());

        // 防止异常积累
        if (times[url].length > 20) {
            times[url] = times[url].slice(-20);
        }

        saveJSON(TIME_KEY, times);
    }

    function getElapsed(url) {
        const times = loadJSON(TIME_KEY);

        if (
            !Array.isArray(times[url]) ||
            !times[url].length
        ) {
            return 0;
        }

        const start = times[url].shift();

        if (!times[url].length) {
            delete times[url];
        }

        saveJSON(TIME_KEY, times);

        return Math.max(0, Date.now() - start);
    }

    // -------------------------
    // 更新 CDN 状态
    // -------------------------

    function updateResult(host, status, elapsed) {
        const hosts = getHosts();

        // 只统计本插件管理的节点
        if (!hosts.includes(host)) return;

        const db = loadJSON(DB_KEY);
        const state = getState(db, host);

        state.lastStatus = status;

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
                " 延迟 " + elapsed + "ms"
            );

        } else if (
            status === 403 ||
            status === 429 ||
            status >= 500
        ) {

            state.failure++;

            // 403 和 429 降权，但不直接冷却
            if (status >= 500) {
                state.streak++;
            } else {
                state.streak = Math.max(
                    0,
                    state.streak - 1
                );
            }

            log(
                "异常 " + host +
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

        // 404 不作为 CDN 节点故障依据
        saveJSON(DB_KEY, db);
    }

    // -------------------------
    // Request Script
    // -------------------------

    function requestHandler() {
        const original = $request.url;

        if (
            !isValidMedia(original) ||
            isRelay(original)
        ) {
            $done({});
            return;
        }

        const hosts = getHosts();
        const originalHost = getHost(original);

        const db = loadJSON(DB_KEY);

        // 已属于管理列表的请求，记录原节点状态
        let selected;

        if (hosts.includes(originalHost)) {
            selected = originalHost;
        } else {
            selected = selectHost(hosts, db);
        }

        // 记录目标 URL 的请求开始时间
        let finalURL = original;

        if (selected !== originalHost) {
            const url = new URL(original);

            // 只修改主机名
            url.hostname = selected;
            url.port = "";

            finalURL = url.toString();
        }

        recordStart(finalURL);

        saveJSON(DB_KEY, db);

        if (finalURL === original) {
            $done({});
            return;
        }

        log(
            originalHost + " -> " + selected
        );

        $done({
            url: finalURL
        });
    }

    // -------------------------
    // Response Script
    // -------------------------

    function responseHandler() {
        const url = $request.url;
        const host = getHost(url);

        const elapsed = getElapsed(url);

        const status = Number(
            $response.status || 0
        );

        updateResult(
            host,
            status,
            elapsed
        );

        $done({});
    }

    // -------------------------
    // 执行入口
    // -------------------------

    try {
        // Loon Response Script 才提供 $response
        if (
            typeof $response !== "undefined" &&
            $response !== null
        ) {
            responseHandler();

        } else {
            requestHandler();
        }

    } catch (error) {

        log("执行异常: " + String(error));

        $done({});
    }

})();
