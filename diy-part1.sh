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
# 注意：不能只把整个仓库扔到 package/ 下然后指望所有子目录都被识别。
# fantastic-packages 实际目录是 fantastic_packages/packages 和 fantastic_packages/luci。
echo ">>> 克隆 fantastic-packages 并以 src-link 方式接入"
rm -rf fantastic_packages 2>/dev/null || true
git clone --depth 1 --branch master --single-branch --no-tags --recurse-submodules \
  https://github.com/fantastic-packages/packages.git fantastic_packages

(
  cd fantastic_packages
  git submodule update --init --recursive
)

cat >> feeds.conf.default <<'EOF_FEEDS'
src-link fantastic_packages_packages fantastic_packages/packages
src-link fantastic_packages_luci fantastic_packages/luci
EOF_FEEDS

echo "===== diy-part1.sh 执行完成 ====="
