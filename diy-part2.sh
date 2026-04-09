#!/bin/bash
# 描述: 闭源满血版 - 终极配置注入版 (拨乱反正正确路径版)

# 1. 基础 IP 和语言配置
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 2. 拉取闭源专用的底层通信驱动和代理辅助包 (还原作者真实的 porxy 拼写)
git clone -b packages --depth 1 https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 https://github.com/shiyu1314/openwrt-feeds package/porxy

# 3. 清理引发死循环的冲突包 (已保留 dockerman)
rm -rf feeds/small/*homeproxy* feeds/small/*momo* feeds/small/*fchomo* feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy* feeds/kenzo/*momo* feeds/kenzo/*fchomo* feeds/kenzo/*nikki*
rm -rf feeds/luci/applications/{luci-app-samba4,luci-app-aria2,luci-app-diskman}
# 注意：如果你要用 mosdns/passwall，请把下面这行里的 v2ray-geodata 删掉，否则会报依赖 Warning
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# 4. 强制替换 Argon 主题
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 5. 克隆 shiyu1314 的补丁仓库并打入补丁 (还原正确的 patch 路径)
echo "正在克隆 shiyu1314 的补丁仓库 (25.12分支)..."
git clone -b 25.12 --depth=1 https://github.com/shiyu1314/openwrt-rax3000m.git /tmp/shiyu_repo

echo "打入底层保命补丁..."
patch -p1 --no-backup-if-mismatch < /tmp/shiyu_repo/patch/diy/001-rust-disable-ci-mode.patch
patch -p1 --no-backup-if-mismatch < /tmp/shiyu_repo/patch/diy/002-include-kernel-Always-collect-module-symvers.patch
patch -p1 --no-backup-if-mismatch < /tmp/shiyu_repo/patch/diy/003-include-netfilter-update-kernel-config-options-for-l.patch
patch -p1 --no-backup-if-mismatch < /tmp/shiyu_repo/patch/diy/004-openwrt-firewall4-add-custom-nft-command-support.patch

# 6. 同步作者的 Rust 版本锁定
RUST_VERSION=1.94.0
RUST_HASH=0b53ae34f5c0c3612cfe1de139f9167a018cd5737bc2205664fd69ba9b25f600
sed -ri "s/(PKG_VERSION:=)[^\"]*/\1$RUST_VERSION/;s/(PKG_HASH:=)[^\"]*/\1$RUST_HASH/" feeds/packages/lang/rust/Makefile

# 7. 内核 Vermagic 校验修复 (防止刷机后无 Wi-Fi)
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 8. 注入 NX30 Pro 高功率 EEPROM (还原正确的 Curl 在线下载方式)
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# 9. 解决 OpenClash 触发的内核弹窗卡死
cat >> target/linux/mediatek/filogic/config-6.12 <<EOF
CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF

# =========================================================
# 10. 【终极绝杀】暴力提取并注入 MTK 闭源驱动所需的硬件宏定义！
# =========================================================
echo "正在注入 MTK 专属内核与驱动配置 (还原正确的 config 路径)..."
grep -E '^(CONFIG_MTK_|CONFIG_CONNINFRA_|CONFIG_WARP_)' /tmp/shiyu_repo/config/config-common >> .config
echo "CONFIG_PACKAGE_kmod-mt_wifi=y" >> .config
echo "CONFIG_PACKAGE_luci-app-mtwifi-cfg=y" >> .config
echo "CONFIG_PACKAGE_mtwifi-cfg-ucode=y" >> .config
# =========================================================

# 11. 首次开机设置
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
