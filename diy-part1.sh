#!/bin/bash
set -e

echo "===== DIY part1: pre-feeds cleanup + Argon UI sources ====="

# 这个脚本运行在 ./scripts/feeds update -a 之前。
# 这里只处理 feeds update 前必须完成的内容：
# 1. 清理旧分支残留的第三方 feeds 配置；
# 2. 预拉取不依赖 feeds install 的独立 package 源。
#
# OpenList、DiskMan、.config、files/、温度修复都在 diy-part2.sh 处理。
# 不要把需要 feeds install 后处理的内容放在这里。

if [ ! -f feeds.conf.default ]; then
    echo "ERROR: feeds.conf.default not found. Are you in OpenWrt source root?"
    exit 1
fi

# 防止旧分支残留第三方 feeds，避免 feeds update 时拉入旧的大包集合。
sed -i '/kenzo/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/fantastic/d' feeds.conf.default
sed -i '/openlist/d' feeds.conf.default
sed -i '/diskman/d' feeds.conf.default
sed -i '/openclash/d' feeds.conf.default
sed -i '/passwall/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default

echo "===== feeds.conf.default after cleanup ====="
cat feeds.conf.default

echo "===== Add luci-theme-argon source ====="
rm -rf package/luci-theme-argon
git clone --depth 1 -b master https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

if [ ! -f package/luci-theme-argon/Makefile ]; then
    echo "ERROR: luci-theme-argon Makefile missing"
    exit 1
fi

echo "===== Add luci-app-argon-config source ====="
rm -rf package/luci-app-argon-config
git clone --depth 1 -b master https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

if [ ! -f package/luci-app-argon-config/Makefile ]; then
    echo "ERROR: luci-app-argon-config Makefile missing"
    exit 1
fi

echo "===== DIY part1 done ====="
