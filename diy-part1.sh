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
# 当前 fantastic-packages README 推荐:
#   src-git --root=feeds fantastic_packages https://github.com/fantastic-packages/packages.git;master
# 这样 scripts/feeds 会按它仓库内 feeds/ 结构生成 packages/luci/special，
# 能正确识别 luci-app-diskman 和 luci-app-temp-status。
echo ">>> 写入 fantastic-packages feed"
cat >> feeds.conf.default <<'EOF_FEEDS'
src-git --root=feeds fantastic_packages https://github.com/fantastic-packages/packages.git;master
EOF_FEEDS

echo "===== diy-part1.sh 执行完成 ====="
