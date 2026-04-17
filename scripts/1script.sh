#!/bin/bash

# 修改默认IP & 固件名称 & 编译署名和时间
#sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='JDC'/g" package/base-files/files/bin/config_generate
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
            _('Firmware Version'),\n \
            E('span', {}, [\n \
                (L.isObject(boardinfo.release)\n \
                ? boardinfo.release.description + ' / '\n \
                : '') + (luciversion || '') + ' / ',\n \
            E('a', {\n \
                href: 'https://github.com/lee29/Libwrt/releases',\n \
                target: '_blank',\n \
                rel: 'noopener noreferrer'\n \
                }, [ 'Built by Lee29 $(date "+%Y-%m-%d %H:%M:%S")' ])\n \
            ]),#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# 移除luci-app-attendedsysupgrade软件包
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 调整NSS驱动q6_region内存区域预留大小（ipq6018.dtsi默认预留85MB，ipq6018-512m.dtsi默认预留55MB，带WiFi必须至少预留54MB，以下分别是改成预留16MB、32MB、64MB和96MB）
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# 移除要替换的包
rm -rf feeds/packages/lang/golang
rm -rf feeds/luci/applications/luci-app-openclash


# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}
#
#
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
#
git_sparse_clone main https://github.com/VIKINGYFY/packages luci-app-wolplus
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/vernesong/OpenClash package/luci-app-openclash
###----------------------------------------------------------------------



#添加迅雷下载
#git clone --depth=1 https://github.com/lee29/thunder-openwrt package/thunder
#chmod +x package/thunder
git clone --depth=1 https://github.com/lee29/xunlei-package package/xunlei
chmod +x package/xunlei
###----------------------------------------------------------------------


# 移除 自带的tindy2013/subconverter核心库，替换为MetaCubeX/subconverter（支持vless）
#rm -rf feeds/packages/libs/{jpcre2,libcron,quickjspp,rapidjson,toml11}
# git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter jpcre2 
# git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter libcron 
# git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter quickjspp 
# git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter rapidjson
# git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter toml11 
#mv -v {jpcre2,libcron,quickjspp,rapidjson,toml11} feeds/packages/libs
#chmod +x feeds/packages/libs/{jpcre2,libcron,quickjspp,rapidjson,toml11}
###-----------------麻烦---------------------------------
# rm -rf feeds/packages/net/{sub-web,subconverter}
# git_sparse_clone master https://github.com/lee29/openwrt-subconverter sub-web
# git_sparse_clone master https://github.com/lee29/openwrt-subconverter subconverter
# mv -v {sub-web,subconverter} feeds/packages/net
# chmod +x feeds/packages/net/{sub-web,subconverter}
###----------------------------------------------------------------------
# 使用单个sed命令完成所有替换
sed -i \
-e 's|^PKG_SOURCE_URL:=https://github.com/tindy2013/subconverter.git$|PKG_SOURCE_URL:=https://github.com/asdlokj1qpi233/subconverter.git|' \
-e 's|^PKG_SOURCE_DATE:=2026-02-27$|PKG_SOURCE_DATE:=2024-03-18|' \
-e 's|^PKG_SOURCE_VERSION:=5b8d3af0d7b659e3ff6029560e4a6811538a9c21$|PKG_SOURCE_VERSION:=cd74f4dc22dc7ce08ebb253e675be68e6d30b28c|' \
-e 's|^PKG_VERSION:=0.9.0$|PKG_VERSION:=0.9.9|' \
-e 's|^PKG_MIRROR_HASH:=a64037584325db8941bec1855c7c96f6d2f37b7626fd62ef8126e8b215a44ae0$|PKG_MIRROR_HASH:=skip|' \
feeds/packages/net/subconverter/Makefile
chmod +x feeds/packages/net/subconverter







### 添加 luci-app-subconverter 订阅转换界面
#git clone --depth=1 https://github.com/0x2196f3/luci-app-subconverter feeds/luci/applications/luci-app-subconverter
#git_sparse_clone main https://github.com/0x2196f3/luci-app-subconverter luci-app-subconverter
#mv -v luci-app-subconverter feeds/luci/applications
#chmod +x feeds/luci/applications/luci-app-subconverter


#内置订阅转换后端配置
#【https://github.com/Aethersailor/Custom_OpenClash_Rules/wiki/%E4%B8%80%E4%BA%9B%E9%9B%B6%E7%A2%8E%E7%9A%84%E6%95%99%E7%A8%8B#11-immortalwrt-%E4%B8%8B%E6%90%AD%E5%BB%BA%E8%AE%A2%E9%98%85%E8%BD%AC%E6%8D%A2%E5%90%8E%E7%AB%AF%E6%9C%8D%E5%8A%A1】
mkdir -p files/etc/subconverter/config
SMART_INI_URL="https://testingcf.jsdelivr.net/gh/Aethersailor/Custom_OpenClash_Rules@main/cfg/Custom_Clash_Lite.ini"
wget -qO- $SMART_INI_URL > files/etc/subconverter/config/Smart.ini
#sed -i 's/custom_proxy_group=🚀 手动选择`select`[]♻️ 自动选择/custom_proxy_group=🚀 手动选择`select`[]♻️ 自动选择`[]♻️ 负载均衡`/g' files/etc/subconverter/config/Smart.ini
#sed -i '/custom_proxy_group=♻️ 自动选择`url-test`.*`https://www.gstatic.com/generate_204`300,,50/a\custom_proxy_group=♻️ 负载均衡`load-balance`.*`http://www.gstatic.com/generate_204`300,,100' files/etc/subconverter/config/Smart.ini
chmod +x files/etc/subconverter/config/Smart.ini
###----------------------------------------------------------------------



###----------------------------------------------------------------------
#内置openclash文件
mkdir -p files/etc/openclash/core
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/smart/clash-linux-arm64.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
COUNTRY_URL="https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb"
ASN_URL="https://raw.githubusercontent.com/xishang0128/geoip/release/GeoLite2-ASN.mmdb"
MODEL_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model-large.bin"
# wget -qO- $CLASH_META_URL | gzip -d > files/etc/openclash/core/mihomo-linux-amd64
wget -qO- $CLASH_META_URL | tar xOvz > files/etc/openclash/core/clash_meta
wget -qO- $GEOIP_URL > files/etc/openclash/GeoIP.dat
wget -qO- $GEOSITE_URL > files/etc/openclash/GeoSite.dat
wget -qO- $COUNTRY_URL > files/etc/openclash/Country.mmdb
wget -qO- $ASN_URL > files/etc/openclash/ASN.mmdb
wget -qO- $MODEL_URL > files/etc/openclash/model.bin
chmod +x files/etc/openclash/core/clash*
###----------------------------------------------------------------------


# 调整插件显示位置
# sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/services/nas/g' package/openlist2/luci-app-openlist2/root/usr/share/luci/menu.d/luci-app-openlist2.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-minidlna/root/usr/share/luci/menu.d/luci-app-minidlna.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-eqos/root/usr/share/luci/menu.d/luci-app-eqos.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-wifischedule/root/usr/share/luci/menu.d/luci-app-wifischedule.json
###----------------------------------------------------------------------


./scripts/feeds update -a
./scripts/feeds install -a
