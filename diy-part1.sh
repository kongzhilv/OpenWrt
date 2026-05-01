#!/bin/bash
set -e

echo "===== DIY part1: official feeds only ====="

# 防止旧分支残留第三方 feeds
sed -i '/kenzo/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/fantastic/d' feeds.conf.default
sed -i '/openlist/d' feeds.conf.default

echo "===== feeds.conf.default ====="
cat feeds.conf.default

echo "===== DIY part1 done ====="
