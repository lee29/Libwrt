#!/usr/bin/env bash

set -e
set -o errexit
set -o errtrace

# 定义错误处理函数
error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
}

# 设置trap捕获ERR信号
trap 'error_handler' ERR

# source /etc/profile
# BASE_PATH=$(cd $(dirname $0) && pwd)

#去除空密码提示
remove_NoPasswordSet() {
    install -Dm755 "$GITHUB_WORKSPACE/patches/luci-theme-argon-header.ut" "$OPENWRT_PATH/package/feeds/luci/luci-theme-argon/ucode/template/themes/argon/header.ut" 
    install -Dm755 "$GITHUB_WORKSPACE/patches/luci-theme-aurora-header.ut" "$OPENWRT_PATH/package/feeds/luci/luci-theme-aurora-header/ucode/template/themes/aurora/header.ut" 
}


add_wifi_default_set() {
    local qualcommax_uci_dir="$OPENWRT_PATH/target/linux/qualcommax/base-files/etc/uci-defaults"
    if [ -d "$qualcommax_uci_dir" ]; then
        install -Dm755 "$GITHUB_WORKSPACE/patches/990_set-wifi-uci.sh" "$qualcommax_uci_dir/990_set-wifi-uci.sh"  
    fi
}

custom_settings() {
    install -Dm755 "$GITHUB_WORKSPACE/patches/991_custom_settings" "$OPENWRT_PATH/package/base-files/files/etc/uci-defaults/991_custom_settings" 
}




fix_build_for_openssl() {
    local openssl_dir="$OPENWRT_PATH/package/libs/openssl"
    local makefile="$openssl_dir/Makefile"
    if [ -d "$(dirname "$makefile")" ] && [ -f "$makefile" ]; then
        if grep -q "3.0.16" "$makefile"; then
            # 替换本地openssl版本
            rm -rf "$openssl_dir"
            cp -rf "$GITHUB_WORKSPACE/patches/openssl" "$openssl_dir"
        fi
    fi
}

fix_mk_def_depends() {
    sed -i 's/libustream-mbedtls/libustream-openssl/g' $OPENWRT_PATH/include/target.mk 2>/dev/null
    if [ -f $OPENWRT_PATH/target/linux/qualcommax/Makefile ]; then
        sed -i 's/wpad-openssl/wpad-mesh-openssl/g' $OPENWRT_PATH/target/linux/qualcommax/Makefile
    fi
}



install_opkg_distfeeds() {
    local emortal_def_dir="$OPENWRT_PATH/package/emortal/default-settings"
    local distfeeds_conf="$emortal_def_dir/files/99-distfeeds.conf"

    if [ -d "$emortal_def_dir" ] && [ ! -f "$distfeeds_conf" ]; then
        cat <<'EOF' >"$distfeeds_conf"
src/gz openwrt_base https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base/
src/gz openwrt_luci https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci/
src/gz openwrt_packages https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages/
src/gz openwrt_routing https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing/
src/gz openwrt_telephony https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony/
EOF

        sed -i "/define Package\/default-settings\/install/a\\
\\t\$(INSTALL_DIR) \$(1)/etc\\n\
\t\$(INSTALL_DATA) ./files/99-distfeeds.conf \$(1)/etc/99-distfeeds.conf\n" $emortal_def_dir/Makefile

        sed -i "/exit 0/i\\
[ -f \'/etc/99-distfeeds.conf\' ] && mv \'/etc/99-distfeeds.conf\' \'/etc/opkg/distfeeds.conf\'\n\
sed -ri \'/check_signature/s@^[^#]@#&@\' /etc/opkg.conf\n" $emortal_def_dir/files/99-default-settings
    fi
}



main() {
    remove_NoPasswordSet
    add_wifi_default_set
    custom_settings
    #fix_build_for_openssl
    #fix_mk_def_depends
    install_opkg_distfeeds
}

main "$@"
