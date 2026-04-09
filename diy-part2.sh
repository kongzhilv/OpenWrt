#!/bin/bash
# 描述: 彻底移除 shiyu 依赖及所有第三方注入的纯净版 (完美适配开源驱动)

# 1. 基础 IP 和语言配置
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 2. 清理引发死循环的冲突包 (已保留 dockerman)
rm -rf feeds/small/*homeproxy* feeds/small/*momo* feeds/small/*fchomo* feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy* feeds/kenzo/*momo* feeds/kenzo/*fchomo* feeds/kenzo/*nikki*
rm -rf feeds/luci/applications/{luci-app-samba4,luci-app-aria2,luci-app-diskman}
# 注意：如果你要用 mosdns/passwall，请把下面这行里的 v2ray-geodata 删掉，否则会报依赖 Warning
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# 3. 强制替换 Argon 主题
rm -rf package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 4. 内核 Vermagic 校验修复 (防止刷机后无 Wi-Fi)
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# 5. 解决 OpenClash 触发的内核弹窗卡死
if ! grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y" target/linux/mediatek/filogic/config-6.12 2>/dev/null; then
cat >> target/linux/mediatek/filogic/config-6.12 <<'EOF'
CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF
fi

# 6. 首次开机设置
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
chmod +x files/etc/uci-defaults/99-custom-setup

# 7. 修复 Rust 在 GitHub Actions / CI 下 host 编译失败
# 你的报错就死在 feeds/packages/lang/rust 的 host 构建阶段
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi
