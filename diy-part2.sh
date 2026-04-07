#!/bin/bash
# 描述: 闭源满血版 - 纯净修复，彻底告别死循环与外链 404

# 1. 基础 IP 和语言配置
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 2. 拉取闭源专用的底层通信驱动和代理辅助包 (原作者核心环境)
git clone -b packages --depth 1 https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 https://github.com/shiyu1314/openwrt-feeds package/porxy

# =========================================================
# 3. 【彻底清理冲突包】防止 Recursive dependency (死循环) 报错
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
# =========================================================
sed -ri "s/(PKG_VERSION:=)[^\"]*/\11.94.0/;s/(PKG_HASH:=)[^\"]*/\10b53ae34f5c0c3612cfe1de139f9167a018cd5737bc2205664fd69ba9b25f600/" feeds/packages/lang/rust/Makefile
sed -i '/download-ci-llvm/d' feeds/packages/lang/rust/Makefile
sed -i '/\[llvm\]/a \download-ci-llvm = false' feeds/packages/lang/rust/Makefile

# =========================================================
# 6. 【替代补丁 002】彻底解决 conninfra 驱动报错
# =========================================================
cat << 'EOF' > /tmp/002-symvers.patch
--- a/include/kernel.mk
+++ b/include/kernel.mk
@@ -160,13 +160,9 @@ PKG_EXTMOD_SUBDIRS ?= .
 PKG_SYMVERS_DIR = $(KERNEL_BUILD_DIR)/symvers
 
 define collect_module_symvers
-	for subdir in $(PKG_EXTMOD_SUBDIRS); do \
-		realdir=$$$$(readlink -f $(PKG_BUILD_DIR)); \
-		grep -F $(PKG_BUILD_DIR) $(PKG_BUILD_DIR)/$$$$subdir/Module.symvers >> $(PKG_BUILD_DIR)/Module.symvers.tmp; \
-		[ "$(PKG_BUILD_DIR)" = "$$$$realdir" ] || \
-			grep -F $$$$realdir $(PKG_BUILD_DIR)/$$$$subdir/Module.symvers >> $(PKG_BUILD_DIR)/Module.symvers.tmp; \
-	done; \
-	sort -u $(PKG_BUILD_DIR)/Module.symvers.tmp > $(PKG_BUILD_DIR)/Module.symvers; \
+	sort -u $(PKG_BUILD_DIR)/Module.symvers > $(PKG_BUILD_DIR)/Module.symvers.tmp; \
+	rm -f $(PKG_BUILD_DIR)/Module.symvers; \
+	mv $(PKG_BUILD_DIR)/Module.symvers.tmp $(PKG_BUILD_DIR)/Module.symvers; \
 	mkdir -p $(PKG_SYMVERS_DIR); \
 	mv $(PKG_BUILD_DIR)/Module.symvers $(PKG_SYMVERS_DIR)/$(PKG_NAME).symvers
 endef
EOF
patch -p1 < /tmp/002-symvers.patch

# =========================================================
# 7. 【替代补丁 003】解决 netfilter 依赖缺失报错
# =========================================================
sed -i '/CONFIG_IP_NF_IPTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables),))' include/netfilter.mk
sed -i '/CONFIG_BRIDGE_NF_EBTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,EBTABLES,CONFIG_BRIDGE_NF_EBTABLES_LEGACY, $(P_EBT)ebtables),))' include/netfilter.mk

# =========================================================
# 8. 【替代补丁 004】添加 fw4 自定义规则支持 (OpenClash 必备)
# =========================================================
cat << 'EOF' > /tmp/004-fw4.patch
--- a/package/network/config/firewall4/Makefile
+++ b/package/network/config/firewall4/Makefile
@@ -38,6 +38,7 @@ endef
 define Package/firewall4/conffiles
 /etc/config/firewall
 /etc/nftables.d/
+/etc/firewall4.user
 endef
 
 define Package/firewall4/install
--- /dev/null
+++ b/package/network/config/firewall4/patches/100-fw4-add-custom-nft-command-support.patch
@@ -0,0 +1,30 @@
+From c359ce4457ac48bb65767ae5415f296e3d25a51d Mon Sep 17 00:00:00 2001
+From: sbwml <admin@cooluc.com>
+Date: Thu, 14 Mar 2024 12:10:03 +0800
+Subject: [PATCH] fw4: add custom nft command support
+
+Signed-off-by: sbwml <admin@cooluc.com>
+---
+ root/etc/firewall4.user | 3 +++
+ root/sbin/fw4           | 3 ++-
+ 2 files changed, 5 insertions(+), 1 deletion(-)
+ create mode 100644 root/etc/firewall4.user
+
+--- /dev/null
++++ b/root/etc/firewall4.user
+@@ -0,0 +1,3 @@
++# This file is interpreted as shell script.
++# Put your custom nft rules here, they will
++# be executed with each firewall (re-)start.
+--- a/root/sbin/fw4
++++ b/root/sbin/fw4
+@@ -33,7 +33,8 @@ start() {
+ 		esac
+ 
+ 		ACTION=start \
+-			utpl -S $MAIN | nft $VERBOSE -f $STDIN
++			utpl -S $MAIN | nft $VERBOSE -f $STDIN \
++			; /bin/sh /etc/firewall4.user
+ 
+ 		ACTION=includes \
+ 			utpl -S $MAIN
EOF
patch -p1 < /tmp/004-fw4.patch

# =========================================================
# 9. 【核心保命】内核 Vermagic 校验修复 (防止刷机后无 Wi-Fi)
# =========================================================
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 10. 注入 NX30 Pro 高功率 EEPROM
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# 11. 解决 OpenClash 触发的内核弹窗卡死
cat >> target/linux/mediatek/filogic/config-6.12 <<EOF
CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF

# 12. 首次开机设置
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
