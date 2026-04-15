#!/bin/bash
# 描述: 官方 OpenWrt + GitHub Actions 稳定自定义脚本
# 本版目标:
# 1. 默认 IP 改为 192.168.2.1
# 2. 默认语言改为中文
# 3. 使用 Argon 主题
# 4. 修复 OpenClash 所需内核选项
# 5. 禁用 AdGuardHome 及其 LuCI 插件
# 6. 修复 Rust 在 CI 环境下 host 编译失败
# 7. 集成 Lucky
# 注意:
# - 本版不加硬件加速
# - 本版不加 Wi-Fi 高功率相关配置
# - 本版不新增额外第三方 feed，Lucky 直接走 package 目录接入

set -e

echo "===== 开始执行 diy-part2.sh ====="

# 1. 基础 IP 和语言配置
echo ">>> 设置默认 IP 和语言"
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

if [ -f feeds/luci/modules/luci-base/root/etc/config/luci ]; then
  sed -i 's/option lang auto/option lang zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true
  sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true
fi

# 2. 清理冲突软件包
echo ">>> 清理冲突软件包"
rm -rf feeds/small/*homeproxy* 2>/dev/null || true
rm -rf feeds/small/*momo* 2>/dev/null || true
rm -rf feeds/small/*fchomo* 2>/dev/null || true
rm -rf feeds/small/*nikki* 2>/dev/null || true

rm -rf feeds/kenzo/*homeproxy* 2>/dev/null || true
rm -rf feeds/kenzo/*momo* 2>/dev/null || true
rm -rf feeds/kenzo/*fchomo* 2>/dev/null || true
rm -rf feeds/kenzo/*nikki* 2>/dev/null || true

rm -rf feeds/luci/applications/luci-app-samba4 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-aria2 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-diskman 2>/dev/null || true

# 清理部分容易冲突的 net 包
rm -rf feeds/packages/net/samba4 2>/dev/null || true
rm -rf feeds/packages/net/v2ray-geodata 2>/dev/null || true
rm -rf feeds/packages/net/mosdns 2>/dev/null || true
rm -rf feeds/packages/net/sing-box 2>/dev/null || true
rm -rf feeds/packages/net/aria2 2>/dev/null || true
rm -rf feeds/packages/net/ariang 2>/dev/null || true

# 3. 明确禁用 AdGuardHome
echo ">>> 禁用 AdGuardHome 相关包"
rm -rf feeds/kenzo/adguardhome 2>/dev/null || true
rm -rf feeds/kenzo/luci-app-adguardhome 2>/dev/null || true
rm -rf feeds/packages/net/adguardhome 2>/dev/null || true

if [ -f .config ]; then
  sed -i '/^CONFIG_PACKAGE_adguardhome=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-adguardhome=/d' .config
  sed -i '/^# CONFIG_PACKAGE_adguardhome is not set/d' .config
  sed -i '/^# CONFIG_PACKAGE_luci-app-adguardhome is not set/d' .config

  cat >> .config <<'EOF'
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_luci-app-adguardhome is not set
EOF
fi

# 4. 强制替换 Argon 主题
echo ">>> 安装 Argon 主题"
rm -rf package/luci-theme-argon 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

if [ -f feeds/luci/collections/luci/Makefile ]; then
  sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
fi

# 4.1 安装 Lucky
echo ">>> 安装 Lucky"
rm -rf package/lucky 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

# 5. 内核 Vermagic 校验修复
echo ">>> 修复 Vermagic"
if [ -f include/kernel-defaults.mk ]; then
  sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
fi

if [ -f target/linux/generic/kernel-6.12 ]; then
  grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic
fi

# 6. OpenClash 所需内核配置
echo ">>> 写入 OpenClash 所需内核配置"
KERNEL_CFG="target/linux/mediatek/filogic/config-6.12"
if [ -f "$KERNEL_CFG" ]; then
  grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y" "$KERNEL_CFG" || cat >> "$KERNEL_CFG" <<'EOF'

CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF
fi

# 7. 首次开机默认配置
echo ">>> 写入首次开机配置"
mkdir -p files/etc/uci-defaults

cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF

chmod +x files/etc/uci-defaults/99-custom-setup

# 8. Rust CI 编译修复
echo ">>> 修复 Rust 在 GitHub Actions / CI 下的 host 编译问题"
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

echo "===== diy-part2.sh 执行完成 ====="
