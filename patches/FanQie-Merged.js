/*
 * FanQie Novel Loon Merged Script
 * Version: 1.0.0
 *
 * Integrated:
 * 1. DYZB.js
 * 2. FQLJ.js
 *
 * Compatible with Loon
 */

(function () {
    "use strict";

    const action = $argument || "";

    // =================================
    // 1. DYZB 推荐内容过滤
    // =================================

    function handleDYZB() {
        let body = $response.body;

        try {
            const obj = JSON.parse(body);

            if (obj.data && Array.isArray(obj.data)) {
                obj.data = obj.data.filter(item => {
                    const content = JSON.stringify(item);

                    return !content.includes("douyin")
                        && !content.includes("直播间");
                });
            }

            body = JSON.stringify(obj);

        } catch (e) {
            console.log("[FanQie] DYZB:", e);
        }

        $done({ body });
    }

    // =================================
    // 2. FQLJ 请求过滤
    // =================================

    function handleFQLJ() {
        if ($request) {
            const url = $request.url.toLowerCase();

            const headers = JSON.stringify(
                $request.headers || {}
            ).toLowerCase();

            if (headers.includes("live")) {
                console.log("[FanQie] Blocked live header");

                $done({
                    response: {
                        status: 403,
                        headers: {
                            "Content-Type": "text/plain"
                        },
                        body: "Blocked"
                    }
                });

                return;
            }

            if (url.includes("img")) {
                console.log("[FanQie] Blocked img URL");

                $done({
                    response: {
                        status: 403,
                        headers: {
                            "Content-Type": "text/plain"
                        },
                        body: "Blocked"
                    }
                });

                return;
            }
        }

        $done({});
    }

    // =================================
    // 3. 执行入口
    // =================================

    try {
        if (action === "dyzb") {
            handleDYZB();
        } else if (action === "fqlj") {
            handleFQLJ();
        } else {
            $done({});
        }
    } catch (e) {
        console.log("[FanQie] Error:", e);
        $done({});
    }

})();
