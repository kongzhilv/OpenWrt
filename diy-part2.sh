#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置

# 1. 修改默认后台 IP 为 192.168.2.1 (防止和光猫冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 动态修复第三方源 (small/kenzo) 中 homeproxy 和 momo 的死循环依赖报错
# 强行删除 Makefile 中导致死循环的错误依赖声明
find feeds/small/ -name "Makefile" -exec sed -i 's/+PACKAGE_sing-box-tiny//g' {} +
find feeds/small/ -name "Makefile" -exec sed -i 's/+PACKAGE_luci-app-momo//g' {} +
find feeds/kenzo/ -name "Makefile" -exec sed -i 's/+PACKAGE_sing-box-tiny//g' {} +
find feeds/kenzo/ -name "Makefile" -exec sed -i 's/+PACKAGE_luci-app-momo//g' {} +
