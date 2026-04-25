#!/bin/bash
# 描述: 第三方 feed / package 接入
# 运行位置: OpenWrt 源码根目录
set -e

echo "===== DIY-part1 ====="

# 1. 清理旧 feed 定义，避免重复追加
echo ">>> 清理旧第三方 feed 定义"
sed -i '/^src-git[[:space:]].*kenzo/d' feeds.conf.default
sed -i '/^src-git[[:space:]].*small/d' feeds.conf.default
sed -i '/^src-git[[:space:]].*fantastic/d' feeds.conf.default
sed -i '/^src-link[[:space:]].*fantastic/d' feeds.conf.default

# 2. 接入 kenzok8 feeds（OpenClash / wechatpush 等）
echo ">>> 写入 kenzo / small feeds"
cat >> feeds.conf.default <<'EOF_FEEDS'
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF_FEEDS

# 3. 正确接入 fantastic-packages
# fantastic-packages README 推荐方式：
# 先 clone，再通过 src-link 接入 fantastic_packages/feeds/packages、feeds/luci、feeds/special
echo ">>> 克隆 fantastic-packages"
rm -rf fantastic_packages 2>/dev/null || true
git clone --branch master --single-branch --no-tags --recurse-submodules \
  https://github.com/fantastic-packages/packages.git fantastic_packages

(
  cd fantastic_packages
  git submodule update --init --recursive
)

echo ">>> 以 src-link 方式接入 fantastic-packages"
cat >> feeds.conf.default <<'EOF_FEEDS'
src-link fantastic_packages_packages fantastic_packages/feeds/packages
src-link fantastic_packages_luci fantastic_packages/feeds/luci
src-link fantastic_packages_special fantastic_packages/feeds/special
EOF_FEEDS

echo "===== diy-part1.sh 执行完成 ====="
