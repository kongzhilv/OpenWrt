#!/bin/bash
# 描述: 官方 OpenWrt + GitHub Actions 稳定自定义脚本
# 目标:
# - 合并仓库根目录 files/ 到 openwrt/files/
# - 温度显示: luci-app-temp-status
# - DiskMan: luci-app-diskman
# - 网页终端: luci-app-ttyd
# - OpenList: OpenListTeam/OpenList-OpenWRT
# - Turbo ACC: luci-app-turboacc，可提供软件流量分载、Shortcut-FE、全锥形 NAT、BBR 等
# - eMMC extroot: 首次启动自动切换到 mmcblk0p6，目标约 1GiB overlay
set -e

echo "===== 开始执行 diy-part2.sh ====="

# 0. 先合并仓库根目录 files/，后续本脚本生成的文件会覆盖同路径旧文件
echo ">>> 合并仓库根目录 files/ 到 openwrt/files/"
mkdir -p files
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "$GITHUB_WORKSPACE/files" ]; then
  cp -a "$GITHUB_WORKSPACE/files/." files/
fi

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

# 4. 接入 Turbo ACC
# 默认完整模式，会引入 luci-app-turboacc、nft-fullcone、shortcut-fe，并 patch firewall4/libnftnl/nftables。
# 如遇 25.12 兼容性问题，可在 workflow env 里改 TURBOACC_MODE: "no-sfe" 或 "off"。
echo ">>> 接入 Turbo ACC"
TURBOACC_MODE="${TURBOACC_MODE:-full}"
if [ "$TURBOACC_MODE" = "off" ]; then
  echo "TURBOACC_MODE=off，跳过 Turbo ACC"
else
  curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o /tmp/add_turboacc.sh
  if [ "$TURBOACC_MODE" = "no-sfe" ]; then
    bash /tmp/add_turboacc.sh --no-sfe
  else
    bash /tmp/add_turboacc.sh
  fi
fi

# 5. Argon 主题
echo ">>> 安装 Argon 主题"
rm -rf package/luci-theme-argon 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
rm -rf package/luci-app-argon-config 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

if [ -f feeds/luci/collections/luci/Makefile ]; then
  sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
fi

# 6. Lucky + eQOS Plus
echo ">>> 安装 Lucky"
rm -rf package/lucky 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

echo ">>> 安装 eQOS Plus"
rm -rf package/luci-app-eqosplus 2>/dev/null || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus.git package/luci-app-eqosplus

# 7. OpenClash 所需内核配置
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

# 8. 规范化 .config
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

  for p in \
    adguardhome luci-app-adguardhome \
    openlist2 luci-app-openlist2 \
    openlist luci-app-openlist luci-i18n-openlist-zh-cn \
    luci-app-diskman luci-i18n-diskman-zh-cn \
    luci-app-temp-status \
    ttyd luci-app-ttyd luci-i18n-ttyd-zh-cn \
    luci-app-argon-config \
    luci-app-turboacc kmod-nft-offload
  do
    sed -i "/^CONFIG_PACKAGE_${p}=/d" .config
    sed -i "/^# CONFIG_PACKAGE_${p} is not set/d" .config
  done

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
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-app-temp-status=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_kmod-nft-offload=y
EOF_CONFIG
fi

# 9. 首次开机基础设置
echo ">>> 写入首次开机基础设置"
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/sysctl.d
mkdir -p files/usr/sbin

cat << 'EOF_UCI' > files/etc/uci-defaults/99-custom-setup
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF_UCI

# 10. BBR 默认配置
echo ">>> 写入 BBR 默认配置"
cat << 'EOF_BBR' > files/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF_BBR

cat << 'EOF_NET' > files/etc/uci-defaults/98-network-optimize
uci -q set network.globals.packet_steering='1'
uci commit network

# SQM/CAKE 与硬件 flow offloading 不建议同时开启
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

exit 0
EOF_NET

# 11. 独立 extroot 修复命令：既可首次启动自动执行，也可 SSH 手动执行
echo ">>> 写入 /usr/sbin/emmc-extroot-setup"
cat << 'EOF_EXTROOT_BIN' > files/usr/sbin/emmc-extroot-setup
#!/bin/sh
set -eu

LOGTAG="emmc-extroot"
LOGFILE="/tmp/emmc-extroot.log"

log() {
    echo "$LOGTAG: $*" | tee -a "$LOGFILE"
    logger -t "$LOGTAG" "$*"
}

[ -b /dev/mmcblk0 ] || { log "/dev/mmcblk0 not found"; exit 0; }
mkdir -p /mnt/extroot /mnt/data

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

if [ ! -b /dev/mmcblk0p7 ]; then
    log "repartitioning /dev/mmcblk0: p6=1GiB extroot, p7=rest data"
    parted -s /dev/mmcblk0 rm 6 || true
    parted -s /dev/mmcblk0 mkpart primary ext4 512MiB 1536MiB
    parted -s /dev/mmcblk0 name 6 extroot
    parted -s /dev/mmcblk0 mkpart primary ext4 1536MiB 100%
    parted -s /dev/mmcblk0 name 7 data
    partprobe /dev/mmcblk0 || true
    sleep 2
fi

block info /dev/mmcblk0p6 | grep -q 'TYPE="ext4"' || {
    log "formatting /dev/mmcblk0p6"
    mkfs.ext4 -F -L extroot /dev/mmcblk0p6
}

block info /dev/mmcblk0p7 | grep -q 'TYPE="ext4"' || {
    log "formatting /dev/mmcblk0p7"
    mkfs.ext4 -F -L data /dev/mmcblk0p7
}

EXTROOT_UUID="$(blkid -s UUID -o value /dev/mmcblk0p6)"
DATA_UUID="$(blkid -s UUID -o value /dev/mmcblk0p7)"

[ -n "$EXTROOT_UUID" ] || { log "failed to get extroot UUID"; exit 1; }
[ -n "$DATA_UUID" ] || { log "failed to get data UUID"; exit 1; }

log "writing /etc/config/fstab"
uci -q delete fstab.extroot || true
uci set fstab.extroot='mount'
uci set fstab.extroot.target='/overlay'
uci set fstab.extroot.uuid="$EXTROOT_UUID"
uci set fstab.extroot.fstype='ext4'
uci set fstab.extroot.enabled='1'
uci set fstab.extroot.enabled_fsck='1'

uci -q delete fstab.data || true
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

if [ ! -e /mnt/extroot/etc/.extroot_emmc_done ]; then
    log "copying current overlay to new extroot"
    tar -C /overlay -cpf - . | tar -C /mnt/extroot -xpf -
fi

mkdir -p /mnt/extroot/etc/config
cp -f /etc/config/fstab /mnt/extroot/etc/config/fstab
mkdir -p /mnt/extroot/etc
: > /etc/.extroot_emmc_done
: > /mnt/extroot/etc/.extroot_emmc_done

sync
umount /mnt/extroot || true
umount /mnt/data || true

log "extroot prepared, rebooting"
reboot
exit 0
EOF_EXTROOT_BIN

chmod +x files/usr/sbin/emmc-extroot-setup

# 12. 首次启动自动执行 extroot
cat << 'EOF_EXTROOT_UCI' > files/etc/uci-defaults/05-emmc-extroot
#!/bin/sh
/usr/sbin/emmc-extroot-setup
exit 0
EOF_EXTROOT_UCI

chmod +x files/etc/uci-defaults/05-emmc-extroot
chmod +x files/etc/uci-defaults/98-network-optimize
chmod +x files/etc/uci-defaults/99-custom-setup

# 13. Rust / CI 兼容性修复
echo ">>> 修复 Rust 在 GitHub Actions / CI 下的 host 编译问题"
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

echo "===== diy-part2.sh 执行完成 ====="
