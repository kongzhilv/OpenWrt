#!/bin/bash
# 描述: 深度同步 shiyu1314 原作者环境的终极脚本

# 1. 基础 IP 和语言配置
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 2. 【关键】拉取原作者修复后的驱动包和代理包 (参考 op.sh 第 14-15 行)
# 这两行解决了你遇到的 conninfra 编译未定义符号报错
git clone -b packages --depth 1 https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 https://github.com/shiyu1314/openwrt-feeds package/porxy

# 3. 清理冲突包 (参考 op.sh 第 17-18 行)
rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-samba4,luci-app-aria2,luci-app-diskman}
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# 4. 强制替换 Argon 主题
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 5. 【核心修复】锁定 Rust 版本并应用 001-004 全套补丁 (参考 op.sh 第 37-43 行)
# 这解决了你在日志中遇到的 Rust 编译卡死问题
echo "应用原作者底层保命补丁..."
mkdir -p /tmp/patches && cd /tmp/patches
REPO_RAW="https://raw.githubusercontent.com/shiyu1314/openwrt-rax3000m-25.12/main/patch/diy"
curl -sLo 001.patch "$REPO_RAW/001-rust-disable-ci-mode.patch"
curl -sLo 002.patch "$REPO_RAW/002-include-kernel-Always-collect-module-symvers.patch"
curl -sLo 003.patch "$REPO_RAW/003-include-netfilter-update-kernel-config-options-for-l.patch"
curl -sLo 004.patch "$REPO_RAW/004-openwrt-firewall4-add-custom-nft-command-support.patch"
cd $GITHUB_WORKSPACE/openwrt
patch -p1 < /tmp/patches/001.patch
patch -p1 < /tmp/patches/002.patch
patch -p1 < /tmp/patches/003.patch
patch -p1 < /tmp/patches/004.patch

# 锁定 Rust 版本 (参考 op.sh 第 47-49 行)
RUST_VERSION=1.94.0
RUST_HASH=0b53ae34f5c0c3612cfe1de139f9167a018cd5737bc2205664fd69ba9b25f600
sed -ri "s/(PKG_VERSION:=)[^\"]*/\1$RUST_VERSION/;s/(PKG_HASH:=)[^\"]*/\1$RUST_HASH/" feeds/packages/lang/rust/Makefile

# 6. 【核心修复】内核 Vermagic 校验修复 (参考 op.sh 第 9-11 行)
# 防止编译出的闭源驱动模块在开机时因版本校验失败而无法加载
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 7. 注入 NX30 Pro 高功率 EEPROM
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# 8. 解决 OpenClash 触发的内核弹窗卡死
cat >> target/linux/mediatek/filogic/config-6.12 <<EOF
CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF

# 9. 首次开机设置
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
