#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置及修复依赖冲突

# 1. 修改默认后台 IP 为 192.168.2.1 (防止和光猫冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 修复 OpenWrt 官方源码与第三方源 kenzok8/small 的依赖死循环报错
# 删除存在语法错误或循环依赖的无用包，防止 make defconfig 解析时崩溃
rm -rf feeds/small/luci-app-homeproxy
rm -rf feeds/small/luci-app-momo
rm -rf feeds/kenzo/luci-app-homeproxy
rm -rf feeds/kenzo/luci-app-momo
