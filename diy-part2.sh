#!/bin/bash
# 描述: 专配 shiyu1314 闭源源码的终极 DIY 脚本

# 1. 修改默认后台 IP 为 192.168.2.1
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 强制修改系统默认语言为简体中文
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 3. 物理删除 kenzok8/small 源中引发“死循环”报错的无用插件
rm -rf feeds/small/*homeproxy* feeds/small/*momo* feeds/small/*fchomo* feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy* feeds/kenzo/*momo* feeds/kenzo/*fchomo* feeds/kenzo/*nikki*

# 4. 单独拉取最新的 Argon 主题源码
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 5. 注入 NX30 Pro 高功率 EEPROM 文件
mkdir -p package/base-files/files/lib/firmware/
curl -sLo package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
cp package/base-files/files/lib/firmware/MT7981_iPAiLNA_EEPROM.bin package/base-files/files/lib/firmware/MT7981_EEPROM.bin

# =========================================================
# 6. 完美复刻原作者核心补丁群 (替代原来所有零散的 sed 修改)
# =========================================================
echo "开始拉取并应用底层保命补丁..."
mkdir -p /tmp/patches && cd /tmp/patches
# 001: 解决 Rust 编译报错
curl -sLo 001.patch "https://raw.githubusercontent.com/shiyu1314/openwrt-rax3000m-25.12/main/patch/diy/001-rust-disable-ci-mode.patch"
# 002: 解决 conninfra / mt_wifi 树外模块 undefined 报错
curl -sLo 002.patch "https://raw.githubusercontent.com/shiyu1314/openwrt-rax3000m-25.12/main/patch/diy/002-include-kernel-Always-collect-module-symvers.patch"
# 003: 解决 iptables 依赖问题
curl -sLo 003.patch "https://raw.githubusercontent.com/shiyu1314/openwrt-rax3000m-25.12/main/patch/diy/003-include-netfilter-update-kernel-config-options-for-l.patch"
# 004: 解决 fw4 自定义防火墙支持 (OpenClash 必需)
curl -sLo 004.patch "https://raw.githubusercontent.com/shiyu1314/openwrt-rax3000m-25.12/main/patch/diy/004-openwrt-firewall4-add-custom-nft-command-support.patch"

cd $GITHUB_WORKSPACE/openwrt
patch -p1 < /tmp/patches/001.patch
patch -p1 < /tmp/patches/002.patch
patch -p1 < /tmp/patches/003.patch
patch -p1 < /tmp/patches/004.patch

# =========================================================
# 7. 解决 OpenClash 触发内核 6.12 弹窗导致的 syncconfig Error 1 卡死
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
# 8. 复刻内核 Vermagic 修复 (防止编译出的模块开机加载失败)
# =========================================================
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# =========================================================
# 9. 植入首次开机初始化脚本：仅设置中文界面
# =========================================================
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang=zh_cn
uci commit luci
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
