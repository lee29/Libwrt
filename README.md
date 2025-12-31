<div align="center">
<h1>OpenWrt — 云编译</h1>

## 特别提示

- **本人不对任何人因使用本固件所遭受的任何理论或实际的损失承担责任！**

- **本固件禁止用于任何商业用途，请务必严格遵守国家互联网使用相关法律规定！**

## 项目说明
- 固件默认管理地址：**`192.168.1.1`** 默认用户：**`root`** 默认密码：**`none`**
- 源码来源：[breeze303](https://github.com/LiBwrt-op/openwrt-6.x) [VIKINGYFY](https://github.com/VIKINGYFY/immortalwrt)
- 云编译来源：[ZqinKing](https://github.com/ZqinKing/wrt_release) [davidtall](https://github.com/davidtall/OpenWRT-CI)
- [laipeng668](https://github.com/laipeng668/openwrt-ci-roc)
-  [haiibo](https://github.com/haiibo/OpenWrt) [视频教程](https://www.youtube.com/watch?v=6j4ofS0GT38&t=507s)

5GHz WIFI不正常，电脑显示连接速度1200mbps，实际拷贝吞吐只有200多。经人提醒手动指定发射功率到20db之后，可以到700mbps的吞吐。驱动默认不填的时候是27db，反而有问题
https://post.smzdm.com/p/a7p2ddel/
如果WiFi想跑满千兆的话，发射功率设置23db，信道选149或者157

## 定制固件
1. 首先要登录 Gihub 账号，然后 Fork 此项目到你自己的 Github 仓库
2. 修改 `configs` 目录对应文件添加或删除插件，或者上传自己的 `xx.config` 配置文件
3. 插件对应名称及功能请参考恩山网友帖子：[OpenWrt软件包全量解释](https://www.right.com.cn/FORUM/forum.php?mod=viewthread&tid=8384897)
4. 如需修改默认 IP、添加或删除插件包以及一些其他设置请在 `Roc-script.sh` 文件内修改
5. 添加或修改 `xx.yml` 文件，最后点击 `Actions` 运行要编译的 `workflow` 即可开始编译
6. 编译大概需要1-2小时，编译完成后在仓库主页 [Releases](https://github.com/laipeng668/openwrt-ci-roc/releases) 对应 Tag 标签内下载固件



##others
[ImmortalWrt 下搭建订阅转换后端服务](https://github.com/Aethersailor/Custom_OpenClash_Rules/wiki/%E4%B8%80%E4%BA%9B%E9%9B%B6%E7%A2%8E%E7%9A%84%E6%95%99%E7%A8%8B#11-immortalwrt-%E4%B8%8B%E6%90%AD%E5%BB%BA%E8%AE%A2%E9%98%85%E8%BD%AC%E6%8D%A2%E5%90%8E%E7%AB%AF%E6%9C%8D%E5%8A%A1).


##files大法参考
[files大法参考](https://github.com/rmoyulong/Lite_OpenWrt/blob/513d683b37ef5a62c9273897f85296c339234ecd/Scripts/universal_init.sh).

##优秀脚本sh参考
[优秀脚本sh参考](https://github.com/rmoyulong/Lite_OpenWrt).

##重启后root密码无法登录
[sshd和dropbear两个服务冲突了](https://cndaqiang.github.io/2024/01/23/openwrt-rax3000m-nand/).
