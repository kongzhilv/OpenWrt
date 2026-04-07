#!/bin/bash
# 描述: 闭源满血版 - 纯净 Sed 修复，彻底告别死循环与外链 404

# 1. 基础 IP 和语言配置
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 2. 拉取闭源专用的底层通信驱动和代理辅助包 (原作者核心环境)
git clone -b packages --depth 1 https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 https://github.com/shiyu1314/openwrt-feeds package/porxy

# =========================================================
# 3. 【彻底清理冲突包】防止 Recursive dependency (死循环) 报错
# 这就是导致你刚才在 make defconfig 瞬间暴毙的原因！
# =========================================================
rm -rf feeds/small/*homeproxy* feeds/small/*momo* feeds/small/*fchomo* feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy* feeds/kenzo/*momo* feeds/kenzo/*fchomo* feeds/kenzo/*nikki*
rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-samba4,luci-app-aria2,luci-app-diskman}
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# 4. 强制替换 Argon 主题
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# =========================================================
# 5. 【替代补丁 001】解决 Rust 编译报错
# 不用 patch，直接暴力锁定 1.94.0 版本并禁用 llvm CI 下载
# =========================================================
sed -ri "s/(PKG_VERSION:=)[^\"]*/\11.94.0/;s/(PKG_HASH:=)[^\"]*/\10b53ae34f5c0c3612cfe1de139f9167a018cd5737bc2205664fd69ba9b25f600/" feeds/packages/lang/rust/Makefile
sed -i '/download-ci-llvm/d' feeds/packages/lang/rust/Makefile
sed -i '/\[llvm\]/a \download-ci-llvm = false' feeds/packages/lang/rust/Makefile

# =========================================================
# 6. 【替代补丁 002】解决 conninfra 驱动报错
# 直接让内核忽略 nm 收集符号表时的报错
# =========================================================
sed -i 's/$(TARGET_CROSS)nm -t x --synthetic/-$(TARGET_CROSS)nm -t x --synthetic/g' include/kernel.mk

# =========================================================
# 7. 【替代补丁 003】解决 netfilter 依赖缺失报错
# =========================================================
sed -i '/CONFIG_IP_NF_IPTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables),))' include/netfilter.mk
sed -i '/CONFIG_BRIDGE_NF_EBTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,EBTABLES,CONFIG_BRIDGE_NF_EBTABLES_LEGACY, $(P_EBT)ebtables),))' include/netfilter.mk

# =========================================================
# 8. 【核心保命】内核 Vermagic 校验修复 (防止刷机后无 Wi-Fi)
# =========================================================
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 9. 注入 NX30 Pro 高功率 EEPROM
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# 10. 解决 OpenClash 触发的内核弹窗卡死
cat >> target/linux/mediatek/filogic/config-6.12 <<EOF
CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF

# 11. 首次开机设置
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
