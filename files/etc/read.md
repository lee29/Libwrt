ImmortalWrt 正确密码无法登录
最近遇到了一个怪事，我给路由器刷了 ImmortalWrt 并重置密码后，过一段时间再次登录 ImmortalWrt 就会发现登录不上了，提示密码错误（密码肯定是对的）。并且我重刷了 ImmortalWrt 之后过一段时间又会这样。

解决办法：

SSH 登录 ImmortalWrt，编辑 /etc/config/rpcd 文件，将前三行注释掉：

#config rpcd
#        option socket /var/run/ubus/ubus.sock
#        option timeout 30

config login
        option username 'root'
        option password '$p$root'
        list read '*'
        list write '*'
然后运行：

/etc/init.d/rpcd restart
这样就可以登录了。
