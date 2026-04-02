#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置和修复冲突

# 1. 修改默认后台 IP 为 192.168.2.1 (防止和光猫冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 物理删除 kenzok8/small 源中引发“死循环”报错的无用插件
# 这样在 make defconfig 扫描依赖时，就不会再报错崩溃了
rm -rf feeds/small/luci-app-homeproxy
rm -rf feeds/small/luci-app-momo
rm -rf feeds/kenzo/luci-app-homeproxy
rm -rf feeds/kenzo/luci-app-momo
