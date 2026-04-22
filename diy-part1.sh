#!/bin/bash
# 描述: 第三方 feed / package 接入
set -e

echo "===== DIY-part1 ====="

# 1. 清理旧 feed 定义，避免重复追加
echo ">>> 清理旧第三方 feed 定义"
sed -i '/^src-git.*kenzo/d' feeds.conf.default
sed -i '/^src-git.*small/d' feeds.conf.default

# 2. 接入 kenzok8 feeds（OpenClash / wechatpush 等）
echo ">>> 写入 kenzo / small feeds"
cat >> feeds.conf.default <<'EOF_FEEDS'
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF_FEEDS

# 3. 接入 fantastic-packages（diskman / temp-status）
echo ">>> 克隆 fantastic-packages 到 package 目录"
rm -rf package/fantastic_packages 2>/dev/null || true
git clone --depth 1 --branch master --single-branch --no-tags --recurse-submodules \
  https://github.com/fantastic-packages/packages package/fantastic_packages

echo "===== diy-part1.sh 执行完成 ====="
