#!/bin/bash
# 描述: 编译前执行，用于添加第三方软件源

# 已经使用 ImmortalWrt 源码，其自带源已包含绝大多数常用插件（OpenClash等）
# 注释掉以下两行，防止和 ImmortalWrt 自带的包发生依赖冲突引发 recursive dependency 报错
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >>feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small' >>feeds.conf.default
