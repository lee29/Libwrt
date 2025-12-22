# 修改默认IP & 固件名称 & 编译署名和时间
#sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
# 移除luci-app-attendedsysupgrade软件包
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 调整NSS驱动q6_region内存区域预留大小（ipq6018.dtsi默认预留85MB，ipq6018-512m.dtsi默认预留55MB，带WiFi必须至少预留54MB，以下分别是改成预留16MB、32MB、64MB和96MB）
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# 移除要替换的包
rm -rf feeds/packages/lang/golang

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}


git_sparse_clone main https://github.com/VIKINGYFY/packages luci-app-wolplus
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config feeds/luci/applications/luci-app-aurora-config
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
#git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang


#添加迅雷下载
#git clone --depth=1 https://github.com/lee29/thunder-openwrt package/thunder
git clone --depth=1 https://github.com/lee29/xunlei-package package/xunlei
chmod +x package/xunlei
###----------------------------------------------------------------------

###----------------------------------------------------------------------
# 移除 subconverter核心库
rm -rf feeds/packages/libs/{jpcre2,libcron,quickjspp,rapidjson,toml11}
rm -rf feeds/packages/net/{sub-web,subconverter}
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter jpcre2 feeds/packages/libs/jpcre2
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter libcron feeds/packages/libs/libcron
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter quickjspp feeds/packages/libs/quickjspp
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter rapidjson feeds/packages/libs/rapidjson
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter toml11 feeds/packages/libs/toml11
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter sub-web feeds/packages/net/sub-web
git_sparse_clone master https://github.com/Dawneng/openwrt-subconverter subconverter feeds/packages/net/subconverter
chmod +x feeds/packages/libs/{jpcre2,libcron,quickjspp,rapidjson,toml11}
chmod +x feeds/packages/net/{sub-web,subconverter}
### 添加 luci-app-subconverter 订阅转换界面
git_sparse_clone main https://github.com/0x2196f3/luci-app-subconverter feeds/luci/applications/luci-app-subconverter
chmod +x feeds/luci/applications/luci-app-subconverter
#内置订阅转换后端服务
#【https://github.com/Aethersailor/Custom_OpenClash_Rules/wiki/%E4%B8%80%E4%BA%9B%E9%9B%B6%E7%A2%8E%E7%9A%84%E6%95%99%E7%A8%8B#11-immortalwrt-%E4%B8%8B%E6%90%AD%E5%BB%BA%E8%AE%A2%E9%98%85%E8%BD%AC%E6%8D%A2%E5%90%8E%E7%AB%AF%E6%9C%8D%E5%8A%A1】
mkdir -p files/etc/subconverter/config
SMART_INI_URL="https://testingcf.jsdelivr.net/gh/Aethersailor/Custom_OpenClash_Rules@main/cfg/Custom_Clash_Lite.ini"
wget -qO- $SMART_INI_URL > files/etc/subconverter/config/Smart.ini
chmod +x files/etc/subconverter/config/Smart.ini



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



# 调整插件显示位置
# sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/services/nas/g' package/openlist2/luci-app-openlist2/root/usr/share/luci/menu.d/luci-app-openlist2.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
# sed -i 's/services/nas/g' feeds/luci/applications/luci-app-minidlna/root/usr/share/luci/menu.d/luci-app-minidlna.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-eqos/root/usr/share/luci/menu.d/luci-app-eqos.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json
# sed -i 's/services/control/g' feeds/luci/applications/luci-app-wifischedule/root/usr/share/luci/menu.d/luci-app-wifischedule.json



./scripts/feeds update -a
./scripts/feeds install -a