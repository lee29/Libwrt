#!/bin/sh
# nikki-cleanup: 检测 nikki 停止后清理 DNS 劫持并恢复 dnsmasq
# 通过 cron 每分钟调用；幂等，可重复执行。

STATE_FILE=/tmp/.nikki-last-state

nikki_running() {
    # 匹配主进程名/命令行，避免误匹配本脚本
    if pgrep -f "/usr/bin/nikki" >/dev/null 2>&1; then
        return 0
    fi
    # 有些版本进程名就是 nikki，补充匹配
    if pgrep -x "nikki" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if nikki_running; then
    echo "running" >"$STATE_FILE"
    exit 0
fi

LAST=$(cat "$STATE_FILE" 2>/dev/null)
[ "$LAST" = "running" ] || { echo "stopped" >"$STATE_FILE"; exit 0; }

logger -t nikki-cleanup "nikki stopped, cleanup DNS hijack ..."

# 1) iptables nat 里指向 1053 的重定向（按实际规则调整端口/链名）
if command -v iptables >/dev/null 2>&1; then
    iptables -t nat -S 2>/dev/null | grep -E "to-ports 1053|1053" | while read -r line; do
        rule=$(printf '%s\n' "$line" | sed 's/^-A //')
        [ -n "$rule" ] && iptables -t nat -D $rule 2>/dev/null
    done
    # 如果 nikki 自建了 nat 链，可按名字清空（示例 nikki/nikki_dns，实际用 iptables -t nat -S 核对）
    for ch in nikki nikki_dns nikki_prerouting; do
        iptables -t nat -S "$ch" >/dev/null 2>&1 && iptables -t nat -F "$ch" 2>/dev/null
    done
fi

# 2) nftables：尝试常见表名，不存在忽略报错
if command -v nft >/dev/null 2>&1; then
    for tbl in nikki nikki_dns inet_nikki; do
        nft list table "$tbl" >/dev/null 2>&1 && nft delete table "$tbl" 2>/dev/null
    done
    # 若用 family inet 且表名为 inet nikki，上面 tbl=inet nikki 已覆盖；如单独 ip/ip6 可再加
fi

# 3) 恢复 dnsmasq 上游（改为你想要的直连 DNS）
if uci -q get dhcp.@dnsmasq[0] >/dev/null 2>&1; then
    uci -q del dhcp.@dnsmasq[0].server
    uci -q add_list dhcp.@dnsmasq[0].server="223.5.5.5"
    uci -q add_list dhcp.@dnsmasq[0].server="119.29.29.29"
    uci -q commit dhcp
    /etc/init.d/dnsmasq restart >/dev/null 2>&1
fi

logger -t nikki-cleanup "cleanup done, dnsmasq restored"
echo "stopped" >"$STATE_FILE"
exit 0
