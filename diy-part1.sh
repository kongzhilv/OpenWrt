#!/bin/bash
set -e

echo "===== DIY part1: official feeds + Argon theme source ====="

# 防止旧分支残留第三方 feeds
sed -i '/kenzo/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/fantastic/d' feeds.conf.default
sed -i '/openlist/d' feeds.conf.default

echo "===== feeds.conf.default ====="
cat feeds.conf.default

echo "===== Add luci-theme-argon source ====="
rm -rf package/luci-theme-argon
git clone --depth 1 -b master https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

echo "===== DIY part1 done ====="
