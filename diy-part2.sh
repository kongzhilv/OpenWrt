#!/bin/bash
# 描述: 官方 OpenWrt + GitHub Actions 稳定自定义脚本
# 本版目标:
# 1. 默认 IP 改为 192.168.2.1
# 2. 默认语言改为中文
# 3. 使用 Argon 主题
# 4. 修复 OpenClash 所需内核选项
# 5. 禁用 AdGuardHome 及其 LuCI 插件
# 6. 禁用 OpenList2 及其 LuCI 插件
# 7. 修复 Rust 在 CI 环境下 host 编译失败
# 8. 集成 Lucky
# 9. 集成 eQOS Plus
# 10. 写入 BBR + SQM 相关默认配置
# 11. 首次开机自动将 eMMC 改成:
#     - mmcblk0p6 = 1GiB ext4 -> /overlay
#     - mmcblk0p7 = 剩余空间 ext4 -> /mnt/data
# 12. 强制修正最终 target 为 cmcc_rax3000m，防止 defconfig 跑偏到 openwrt_one

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

# 3.1 明确禁用 OpenList2
echo ">>> 禁用 OpenList2 相关包"
rm -rf feeds/kenzo/openlist2 2>/dev/null || true
rm -rf feeds/kenzo/luci-app-openlist2 2>/dev/null || true

if [ -f .config ]; then
  # 删除旧项
  sed -i '/^CONFIG_PACKAGE_adguardhome=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-adguardhome=/d' .config
  sed -i '/^# CONFIG_PACKAGE_adguardhome is not set/d' .config
  sed -i '/^# CONFIG_PACKAGE_luci-app-adguardhome is not set/d' .config

  sed -i '/^CONFIG_PACKAGE_openlist2=/d' .config
  sed -i '/^CONFIG_PACKAGE_luci-app-openlist2=/d' .config
  sed -i '/^# CONFIG_PACKAGE_openlist2 is not set/d' .config
  sed -i '/^# CONFIG_PACKAGE_luci-app-openlist2 is not set/d' .config

  cat >> .config <<'EOF'
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_luci-app-adguardhome is not set
# CONFIG_PACKAGE_openlist2 is not set
# CONFIG_PACKAGE_luci-app-openlist2 is not set
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

# 4.2 安装 eQOS Plus
echo ">>> 安装 eQOS Plus"
rm -rf package/luci-app-eqosplus 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus.git package/luci-app-eqosplus

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

# 7. 首次开机：基础 LuCI 默认设置
echo ">>> 写入首次开机基础设置"
mkdir -p files/etc/uci-defaults

cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF

# 8. 首次开机：BBR + Packet Steering
echo ">>> 写入 BBR 与网络优化默认配置"

mkdir -p files/etc/sysctl.d
cat << 'EOF' > files/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

cat << 'EOF' > files/etc/uci-defaults/98-network-optimize
uci -q set network.globals.packet_steering='1'
uci commit network

# 不在这里开启硬件 flow offloading
# 因为你后续可能使用 SQM / eQOS Plus / OpenClash
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

exit 0
EOF

# 9. 首次开机：eMMC 自动改成 1GiB overlay + 剩余 data
echo ">>> 写入 eMMC extroot 初始化脚本"

cat << 'EOF' > files/etc/uci-defaults/95-emmc-extroot
#!/bin/sh
set -eu

LOGTAG="emmc-extroot"
SCRIPT_NAME="$(basename "$0")"

log() {
    logger -t "$LOGTAG" "$*"
    echo "$LOGTAG: $*"
}

# 如果已经完成过，或者当前 overlay 已经是 mmcblk0p6，则直接结束
if [ -e /etc/.extroot_emmc_done ] || mount | grep -q '^/dev/mmcblk0p6 on /overlay '; then
    log "extroot already done, skip"
    exit 0
fi

# 只在预期设备上运行
[ -b /dev/mmcblk0 ] || { log "/dev/mmcblk0 not found"; exit 0; }
[ -b /dev/fitrw ] || { log "/dev/fitrw not found, skip"; exit 0; }

# 依赖工具检查
command -v parted >/dev/null 2>&1 || { log "parted missing"; exit 1; }
command -v mkfs.ext4 >/dev/null 2>&1 || { log "mkfs.ext4 missing"; exit 1; }
command -v blkid >/dev/null 2>&1 || { log "blkid missing"; exit 1; }
[ -x /sbin/block ] || { log "/sbin/block missing (block-mount not included)"; exit 1; }

mkdir -p /mnt/extroot /mnt/data

# 防止旧的 p6 被自动挂载
umount /mnt/mmcblk0p6 2>/dev/null || true
umount /mnt/extroot 2>/dev/null || true
umount /mnt/data 2>/dev/null || true

# 如果 p7 不存在，说明还没做过分区，执行一次性重分区
if [ ! -b /dev/mmcblk0p7 ]; then
    log "repartitioning /dev/mmcblk0: p6=1GiB extroot, p7=rest data"

    # 只动 p6，前面的系统分区不碰
    parted -s /dev/mmcblk0 rm 6
    parted -s /dev/mmcblk0 mkpart primary ext4 512MiB 1536MiB
    parted -s /dev/mmcblk0 name 6 extroot
    parted -s /dev/mmcblk0 mkpart primary ext4 1536MiB 100%
    parted -s /dev/mmcblk0 name 7 data

    partprobe /dev/mmcblk0 || true
    sleep 2
fi

# 格式化
log "formatting /dev/mmcblk0p6 and /dev/mmcblk0p7"
mkfs.ext4 -F -L extroot /dev/mmcblk0p6
mkfs.ext4 -F -L data /dev/mmcblk0p7

EXTROOT_UUID="$(blkid -s UUID -o value /dev/mmcblk0p6)"
DATA_UUID="$(blkid -s UUID -o value /dev/mmcblk0p7)"

[ -n "$EXTROOT_UUID" ] || { log "failed to get extroot UUID"; exit 1; }
[ -n "$DATA_UUID" ] || { log "failed to get data UUID"; exit 1; }

# 先在当前 overlay 里写 fstab
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

# 挂载新分区
mount /dev/mmcblk0p6 /mnt/extroot
mount /dev/mmcblk0p7 /mnt/data

# 复制当前 overlay 到新 extroot
log "copying current overlay to new extroot"
tar -C /overlay -cpf - . | tar -C /mnt/extroot -xpf -

# 写完成标记
touch /etc/.extroot_emmc_done
touch /mnt/extroot/etc/.extroot_emmc_done

# 防止该脚本在当前 overlay 或新 extroot 中再次执行
rm -f "/etc/uci-defaults/$SCRIPT_NAME"
rm -f "/mnt/extroot/etc/uci-defaults/$SCRIPT_NAME"

sync
umount /mnt/extroot || true
umount /mnt/data || true

log "extroot prepared, rebooting"
reboot

exit 0
EOF

chmod +x files/etc/uci-defaults/95-emmc-extroot
chmod +x files/etc/uci-defaults/98-network-optimize
chmod +x files/etc/uci-defaults/99-custom-setup

# 10. Rust CI 编译修复
echo ">>> 修复 Rust 在 GitHub Actions / CI 下的 host 编译问题"
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

# 11. 强制修正目标机型，防止 defconfig 跑偏到 openwrt_one
echo ">>> 强制修正目标机型为 cmcc_rax3000m"
if [ -f .config ]; then
  sed -i '/^CONFIG_TARGET_DEVICE_/d' .config
  sed -i '/^CONFIG_TARGET_PROFILE=/d' .config
  sed -i '/^CONFIG_TARGET_BOARD=/d' .config
  sed -i '/^CONFIG_TARGET_SUBTARGET=/d' .config

  sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_openwrt_one=/d' .config
  sed -i '/^# CONFIG_TARGET_mediatek_filogic_DEVICE_openwrt_one is not set/d' .config
  sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=/d' .config
  sed -i '/^# CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m is not set/d' .config

  cat >> .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
EOF
fi

echo "===== diy-part2.sh 执行完成 ====="
