#!/bin/bash
# 描述: 官方 OpenWrt + GitHub Actions 稳定自定义脚本
# 方案: 插件法
# - 温度显示: luci-app-temp-status
# - DiskMan: luci-app-diskman
# - ttyd: luci-app-ttyd
# - OpenList: luci-app-openlist
# - eMMC extroot: 首次启动自动切换到 mmcblk0p6 (1GiB)

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

# 清理旧 OpenList2 / AdGuardHome
echo ">>> 清理旧 OpenList2 / AdGuardHome"
rm -rf feeds/kenzo/openlist2 2>/dev/null || true
rm -rf feeds/kenzo/luci-app-openlist2 2>/dev/null || true
rm -rf package/openlist 2>/dev/null || true
rm -rf feeds/kenzo/adguardhome 2>/dev/null || true
rm -rf feeds/kenzo/luci-app-adguardhome 2>/dev/null || true
rm -rf feeds/packages/net/adguardhome 2>/dev/null || true

# 3. 接入 OpenList 官方 OpenWrt 包
echo ">>> 接入 OpenList 官方 OpenWrt 包"
git clone --depth=1 https://github.com/OpenListTeam/OpenList-OpenWRT package/openlist

# 4. Argon 主题
echo ">>> 安装 Argon 主题"
rm -rf package/luci-theme-argon 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
rm -rf package/luci-app-argon-config 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
if [ -f feeds/luci/collections/luci/Makefile ]; then
  sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
fi

# 5. Lucky + eQOS Plus
echo ">>> 安装 Lucky"
rm -rf package/lucky 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

echo ">>> 安装 eQOS Plus"
rm -rf package/luci-app-eqosplus 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus.git package/luci-app-eqosplus

# 6. OpenClash 所需内核配置
echo ">>> 写入 OpenClash 所需内核配置"
KERNEL_CFG="target/linux/mediatek/filogic/config-6.12"
if [ -f "$KERNEL_CFG" ]; then
  grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y" "$KERNEL_CFG" || cat >> "$KERNEL_CFG" <<'EOF_KERNEL'

CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NF_CONNTRACK_ZONES=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_PROCFS=y
CONFIG_NETFILTER_INGRESS=y
EOF_KERNEL
fi

# 7. 规范化 .config 中的目标与关键包选择
echo ">>> 修正目标机型与关键包"
if [ -f .config ]; then
  sed -i '/^CONFIG_TARGET_DEVICE_/d' .config
  sed -i '/^CONFIG_TARGET_PROFILE=/d' .config
  sed -i '/^CONFIG_TARGET_BOARD=/d' .config
  sed -i '/^CONFIG_TARGET_SUBTARGET=/d' .config

  sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_openwrt_one=/d' .config
  sed -i '/^# CONFIG_TARGET_mediatek_filogic_DEVICE_openwrt_one is not set/d' .config
  sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=/d' .config
  sed -i '/^# CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m is not set/d' .config

  sed -i '/^CONFIG_PACKAGE_adguardhome=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-adguardhome=/d' .config
  sed -i '/^CONFIG_PACKAGE_openlist2=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-openlist2=/d' .config
  sed -i '/^CONFIG_PACKAGE_openlist=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-openlist=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-diskman=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-temp-status=/d' .config
  sed -i '/^CONFIG_PACKAGE_ttyd=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-ttyd=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-argon-config=/d' .config

  cat >> .config <<'EOF_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_luci-app-adguardhome is not set
# CONFIG_PACKAGE_openlist2 is not set
# CONFIG_PACKAGE_luci-app-openlist2 is not set
CONFIG_PACKAGE_openlist=y
CONFIG_PACKAGE_luci-app-openlist=y
CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-temp-status=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-argon-config=y
EOF_CONFIG
fi

# 8. 首次开机：基础 LuCI 默认设置
echo ">>> 写入首次开机基础设置"
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/sysctl.d

cat << 'EOF_UCI' > files/etc/uci-defaults/99-custom-setup
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF_UCI

# 9. BBR 默认配置
echo ">>> 写入 BBR 默认配置"
cat << 'EOF_BBR' > files/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF_BBR

cat << 'EOF_NET' > files/etc/uci-defaults/98-network-optimize
uci -q set network.globals.packet_steering='1'
uci commit network

# SQM/CAKE 与硬件 flow offloading 不建议同时开
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

exit 0
EOF_NET

# 10. eMMC 自动 extroot：p6 -> /overlay (1GiB), p7 -> /mnt/data
echo ">>> 写入 eMMC extroot 初始化脚本"
cat << 'EOF_EXTROOT' > files/etc/uci-defaults/95-emmc-extroot
#!/bin/sh
set -eu

LOGTAG="emmc-extroot"
SCRIPT_NAME="$(basename "$0")"

log() {
    logger -t "$LOGTAG" "$*"
    echo "$LOGTAG: $*"
}

[ -b /dev/mmcblk0 ] || { log "/dev/mmcblk0 not found"; exit 0; }
mkdir -p /mnt/extroot /mnt/data

# 如果 extroot 已经接管，直接退出
if mount | grep -q '^/dev/mmcblk0p6 on /overlay '; then
    log "extroot already active"
    exit 0
fi

command -v parted >/dev/null 2>&1 || { log "parted missing"; exit 1; }
command -v mkfs.ext4 >/dev/null 2>&1 || { log "mkfs.ext4 missing"; exit 1; }
command -v blkid >/dev/null 2>&1 || { log "blkid missing"; exit 1; }
[ -x /sbin/block ] || { log "/sbin/block missing"; exit 1; }

umount /mnt/extroot 2>/dev/null || true
umount /mnt/data 2>/dev/null || true

# 不存在 p7 时才重分区；已存在则直接复用
if [ ! -b /dev/mmcblk0p7 ]; then
    log "repartitioning /dev/mmcblk0"
    parted -s /dev/mmcblk0 rm 6
    parted -s /dev/mmcblk0 mkpart primary ext4 512MiB 1536MiB
    parted -s /dev/mmcblk0 name 6 extroot
    parted -s /dev/mmcblk0 mkpart primary ext4 1536MiB 100%
    parted -s /dev/mmcblk0 name 7 data
    partprobe /dev/mmcblk0 || true
    sleep 2
fi

# 若不是 ext4，则格式化；若已经是 ext4，则保留现有内容
block info /dev/mmcblk0p6 | grep -q 'TYPE="ext4"' || mkfs.ext4 -F -L extroot /dev/mmcblk0p6
block info /dev/mmcblk0p7 | grep -q 'TYPE="ext4"' || mkfs.ext4 -F -L data /dev/mmcblk0p7

EXTROOT_UUID="$(blkid -s UUID -o value /dev/mmcblk0p6)"
DATA_UUID="$(blkid -s UUID -o value /dev/mmcblk0p7)"

[ -n "$EXTROOT_UUID" ] || { log "failed to get extroot UUID"; exit 1; }
[ -n "$DATA_UUID" ] || { log "failed to get data UUID"; exit 1; }

log "writing /etc/config/fstab"
uci -q delete fstab.extroot
uci set fstab.extroot='mount'
uci set fstab.extroot.target='/overlay'
uci set fstab.extroot.uuid="$EXTROOT_UUID"
uci set fstab.extroot.fstype='ext4'
uci set fstab.extroot.enabled='1'
uci set fstab.extroot.enabled_fsck='1'

uci -q delete fstab.data
uci set fstab.data='mount'
uci set fstab.data.target='/mnt/data'
uci set fstab.data.uuid="$DATA_UUID"
uci set fstab.data.fstype='ext4'
uci set fstab.data.enabled='1'
uci set fstab.data.enabled_fsck='1'

uci commit fstab
/etc/init.d/fstab enable

mount /dev/mmcblk0p6 /mnt/extroot
mount /dev/mmcblk0p7 /mnt/data

# 把当前 overlay 内容复制到 extroot
log "copying current overlay to new extroot"
tar -C /overlay -cpf - . | tar -C /mnt/extroot -xpf -
mkdir -p /mnt/extroot/etc/config
cp -f /etc/config/fstab /mnt/extroot/etc/config/fstab

# 避免重复执行
mkdir -p /mnt/extroot/etc
: > /etc/.extroot_emmc_done
: > /mnt/extroot/etc/.extroot_emmc_done
rm -f "/etc/uci-defaults/$SCRIPT_NAME"
rm -f "/mnt/extroot/etc/uci-defaults/$SCRIPT_NAME"

sync
umount /mnt/extroot || true
umount /mnt/data || true
log "extroot prepared, rebooting"
reboot
exit 0
EOF_EXTROOT

chmod +x files/etc/uci-defaults/95-emmc-extroot
chmod +x files/etc/uci-defaults/98-network-optimize
chmod +x files/etc/uci-defaults/99-custom-setup

# 11. Rust / CI 兼容性修复
echo ">>> 修复 Rust 在 GitHub Actions / CI 下的 host 编译问题"
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

echo "===== diy-part2.sh 执行完成 ====="
