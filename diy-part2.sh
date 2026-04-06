#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置和修复冲突

# 1. 修改默认后台 IP 为 192.168.2.1
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 物理删除 kenzok8/small 源中引发“死循环”报错的无用插件
rm -rf feeds/small/*homeproxy*
rm -rf feeds/small/*momo*
rm -rf feeds/small/*fchomo*
rm -rf feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy*
rm -rf feeds/kenzo/*momo*
rm -rf feeds/kenzo/*fchomo*
rm -rf feeds/kenzo/*nikki*

# 3. 单独拉取最新的 Argon 主题源码
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# 4. 强制将默认主题由 bootstrap 替换为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 5. 暴力修复 Rust 编译交叉冲突
sed -i '/download-ci-llvm/d' feeds/packages/lang/rust/Makefile
sed -i '/\[llvm\]/a \download-ci-llvm = false' feeds/packages/lang/rust/Makefile

# 6. 强制修改系统默认语言为简体中文 (统一使用 zh_cn 标签)
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 7. 注入 NX30 Pro 高功率 EEPROM 文件 (替换为闭源专属路径和名称)
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# 8. 修复内核 6.12 遗留 iptables 的配置依赖 (防止 OpenClash 编译或启动失败)
sed -i '/CONFIG_IP_NF_IPTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables),))' include/netfilter.mk
sed -i '/CONFIG_BRIDGE_NF_EBTABLES,/a $(eval $(if $(NF_KMOD),$(call nf_add,EBTABLES,CONFIG_BRIDGE_NF_EBTABLES_LEGACY, $(P_EBT)ebtables),))' include/netfilter.mk

# =========================================================
# 9. 终极修复：解决 OpenClash 触发内核 6.12 弹窗导致的 syncconfig Error 1 卡死
# =========================================================
echo "注入缺失的内核防火墙配置..."
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

# =========================================================
# 植入首次开机初始化脚本：仅设置中文界面
# (无需破解国家代码，闭源驱动带专属管理面板，后台直接改)
# =========================================================
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh

uci -q set luci.main.lang=zh_cn
uci commit luci

rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
# =========================================================
