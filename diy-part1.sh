#!/bin/bash
# 描述: 编译前执行，用于处理 feeds
# 目标: 先确保官方 OpenWrt 机型选择稳定，不引入第三方 feed 污染

# 暂时不追加第三方软件源
# 先保证 RAX3000M 机型能稳定通过 defconfig 与编译
# 后续机型稳定后，再按需逐个加回第三方源
# echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
# echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default

echo "使用官方 feeds，不加载 kenzo / small 第三方源"
