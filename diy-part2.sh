#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置

# 修改默认后台 IP 为 192.168.2.1 (防止和光猫冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
