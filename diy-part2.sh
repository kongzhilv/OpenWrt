#!/bin/bash
set -e

echo "===== DIY part2: fixed minimal DiskMan test - RAX3000M F50 WiFi SFTP ttyd Argon OpenList DiskMan ====="

# 默认 IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true

echo "===== Add OpenList source ====="

# OpenList 官方建议替换 golang feed
if [ -d feeds/packages ]; then
    rm -rf feeds/packages/lang/golang
    mkdir -p feeds/packages/lang
    git clone --depth 1 -b 24.x https://github.com/OpenListTeam/packages_lang_golang.git feeds/packages/lang/golang
else
    echo "WARNING: feeds/packages not found, skip golang replacement"
fi

rm -rf package/openlist
git clone --depth 1 https://github.com/OpenListTeam/OpenList-OpenWRT.git package/openlist

echo "===== Add DiskMan source ====="

# 重点：
# 不要把整个仓库直接放到 package/luci-app-diskman。
# 原仓库真正的 OpenWrt 包在 applications/luci-app-diskman。
# 这里先 clone 到 /tmp，再把应用包目录复制到 package/luci-app-diskman。
rm -rf package/luci-app-diskman
rm -rf /tmp/luci-app-diskman-src

git clone --depth 1 https://github.com/lisaac/luci-app-diskman.git /tmp/luci-app-diskman-src

if [ ! -f /tmp/luci-app-diskman-src/applications/luci-app-diskman/Makefile ]; then
    echo "ERROR: DiskMan application Makefile not found"
    find /tmp/luci-app-diskman-src -maxdepth 5 -type f -name Makefile -print || true
    exit 1
fi

cp -a /tmp/luci-app-diskman-src/applications/luci-app-diskman package/luci-app-diskman

if [ ! -d package/luci-app-diskman ]; then
    echo "ERROR: package/luci-app-diskman missing after copy"
    exit 1
fi

if [ ! -f package/luci-app-diskman/Makefile ]; then
    echo "ERROR: package/luci-app-diskman/Makefile missing after copy"
    find package/luci-app-diskman -maxdepth 5 -type f -print || true
    exit 1
fi

echo "===== Fix DiskMan LuCI translation dirs ====="

# OpenWrt 新 LuCI 语言目录用 zh_Hans / zh_Hant。
# lisaac/luci-app-diskman 老仓库里是 zh-cn / zh-tw。
# 这里强制重命名，并打印结果，防止日志里看不出来有没有生效。
if [ -d package/luci-app-diskman/po/zh-cn ]; then
    rm -rf package/luci-app-diskman/po/zh_Hans
    mv package/luci-app-diskman/po/zh-cn package/luci-app-diskman/po/zh_Hans
fi

if [ -d package/luci-app-diskman/po/zh-tw ]; then
    rm -rf package/luci-app-diskman/po/zh_Hant
    mv package/luci-app-diskman/po/zh-tw package/luci-app-diskman/po/zh_Hant
fi

echo "===== DiskMan po dirs after fix ====="
find package/luci-app-diskman/po -maxdepth 2 -type f -name '*.po' | sort || true

echo "===== Rewrite DiskMan Makefile cleanly ====="

# 关键修复：
# 上一版用正则 patch DEPENDS:= 时，误匹配了 LUCI_DEPENDS:= 里的 DEPENDS，
# 导致 Makefile 被改坏，只剩 LUCI_DEPENDS 后面跟一个孤立 endef。
# 这里不再正则 patch，而是直接重写一个干净的 LuCI Makefile。
cat > package/luci-app-diskman/Makefile <<'EOF_DISKMAN_MAKEFILE'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-diskman
LUCI_NAME:=luci-app-diskman
PKG_VERSION:=0.2.13
PKG_RELEASE:=1

PKG_MAINTAINER:=lisaac <https://github.com/lisaac/luci-app-diskman>
PKG_LICENSE:=AGPL-3.0

LUCI_TITLE:=Disk Manager interface for LuCI
LUCI_DESCRIPTION:=Disk Manager interface for LuCI

# 最小化依赖：
# 保留 DiskMan 基础页面需要的 LuCI / 磁盘工具。
# 不引入 rpcd-mod-file、USB storage、block-mount、ext4、btrfs/exfat/ntfs/f2fs 等重包。
LUCI_DEPENDS:=+luci-compat +luci-lib-ipkg +e2fsprogs +parted +smartmontools +blkid +lsblk

define Package/$(PKG_NAME)/config
config PACKAGE_$(PKG_NAME)_INCLUDE_ntfs_3g_utils
	depends on PACKAGE_$(PKG_NAME)
	bool "Include ntfs-3g-utils"
	default n

config PACKAGE_$(PKG_NAME)_INCLUDE_btrfs_progs
	depends on PACKAGE_$(PKG_NAME)
	bool "Include btrfs-progs"
	default n

config PACKAGE_$(PKG_NAME)_INCLUDE_lsblk
	depends on PACKAGE_$(PKG_NAME)
	bool "Include lsblk"
	default n

config PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	depends on PACKAGE_$(PKG_NAME)
	bool "Include mdadm"
	default n

config PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_raid456
	depends on PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	bool "Include kmod-md-raid456"
	default n

config PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_linears
	depends on PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	bool "Include kmod-md-linear"
	default n
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF_DISKMAN_MAKEFILE

echo "===== DiskMan Makefile after rewrite ====="
sed -n '1,220p' package/luci-app-diskman/Makefile

echo "===== DiskMan package tree check ====="
find package/luci-app-diskman -maxdepth 3 -type d | sort || true
find package/luci-app-diskman -maxdepth 4 -type f -iname '*.po' | sort || true

# 清掉旧 files，避免旧 F50/extroot/OpenClash/TempInfo 脚本进入固件
rm -rf files
mkdir -p files/etc/uci-defaults

# 直接重写 .config，避免 openwrt_one 或旧包残留
cat > .config <<'EOF_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y

# LuCI
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# LuCI Argon theme
CONFIG_PACKAGE_luci-theme-argon=y

# SFTP
CONFIG_PACKAGE_openssh-sftp-server=y

# Web terminal
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y

# OpenList
CONFIG_PACKAGE_openlist=y
CONFIG_PACKAGE_luci-app-openlist=y
CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=y

# Minimal DiskMan LuCI test
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lua-runtime=y
CONFIG_PACKAGE_luci-lib-base=y
CONFIG_PACKAGE_luci-lib-nixio=y
CONFIG_PACKAGE_luci-lib-ip=y
CONFIG_PACKAGE_luci-lib-jsonc=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_lua=y
CONFIG_PACKAGE_libubus-lua=y
CONFIG_PACKAGE_liblucihttp-lua=y
CONFIG_PACKAGE_ucode-mod-lua=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_partx-utils=y
CONFIG_PACKAGE_losetup=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_smartmontools=y

# Common tools
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_vim=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_tree=y
CONFIG_PACKAGE_lsof=y
CONFIG_PACKAGE_procps-ng-ps=y
CONFIG_PACKAGE_procps-ng-free=y
CONFIG_PACKAGE_procps-ng-pgrep=y
CONFIG_PACKAGE_procps-ng-pkill=y
CONFIG_PACKAGE_procps-ng-top=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_coreutils-nohup=y
CONFIG_PACKAGE_coreutils-stat=y
CONFIG_PACKAGE_coreutils-timeout=y

# Network tools
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_mtr-json=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_arp-scan=y

# WiFi
CONFIG_PACKAGE_kmod-mt76=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_wireless-regdb=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y

# USB / F50 network only
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y

# DiskMan optional features must stay disabled
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_ntfs_3g_utils is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_btrfs_progs is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_mdadm is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_kmod_md_raid456 is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_kmod_md_linears is not set

# Must stay disabled in fixed Minimal DiskMan test
# CONFIG_PACKAGE_rpcd-mod-file is not set
# CONFIG_PACKAGE_luci-app-argon-config is not set
# CONFIG_PACKAGE_kmod-usb-storage is not set
# CONFIG_PACKAGE_kmod-usb-storage-uas is not set
# CONFIG_PACKAGE_block-mount is not set
# CONFIG_PACKAGE_kmod-fs-ext4 is not set
# CONFIG_PACKAGE_mount-utils is not set
# CONFIG_PACKAGE_btrfs-progs is not set
# CONFIG_PACKAGE_kmod-fs-btrfs is not set
# CONFIG_PACKAGE_kmod-fs-exfat is not set
# CONFIG_PACKAGE_kmod-fs-msdos is not set
# CONFIG_PACKAGE_kmod-fs-ntfs3 is not set
# CONFIG_PACKAGE_kmod-fs-vfat is not set
# CONFIG_PACKAGE_dosfstools is not set
# CONFIG_PACKAGE_exfat-fsck is not set
# CONFIG_PACKAGE_exfat-mkfs is not set
# CONFIG_PACKAGE_f2fsck is not set
# CONFIG_PACKAGE_mkf2fs is not set
# CONFIG_PACKAGE_libf2fs6 is not set
# CONFIG_PACKAGE_ntfs-3g-utils is not set
# CONFIG_PACKAGE_mdadm is not set
# CONFIG_PACKAGE_kmod-md-linear is not set
# CONFIG_PACKAGE_kmod-md-raid0 is not set
# CONFIG_PACKAGE_kmod-md-raid1 is not set
# CONFIG_PACKAGE_kmod-md-raid10 is not set
# CONFIG_PACKAGE_kmod-md-raid456 is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-mbim is not set
# CONFIG_PACKAGE_kmod-usb-net-qmi-wwan is not set
# CONFIG_PACKAGE_kmod-usb-wdm is not set
# CONFIG_PACKAGE_kmod-usb-serial is not set
# CONFIG_PACKAGE_kmod-usb-serial-option is not set
# CONFIG_PACKAGE_kmod-usb-serial-wwan is not set
# CONFIG_PACKAGE_kmod-usb-acm is not set
# CONFIG_PACKAGE_usb-modeswitch is not set
# CONFIG_PACKAGE_kmod-usb-net-ipheth is not set
# CONFIG_PACKAGE_usbmuxd is not set
# CONFIG_PACKAGE_libimobiledevice is not set
# CONFIG_PACKAGE_luci-app-openclash is not set
# CONFIG_PACKAGE_luci-app-turboacc is not set
# CONFIG_PACKAGE_luci-app-lucky is not set
# CONFIG_PACKAGE_luci-app-eqosplus is not set
# CONFIG_PACKAGE_dockerd is not set
# CONFIG_PACKAGE_docker-compose is not set
# CONFIG_PACKAGE_luci-app-dockerman is not set
EOF_CONFIG

cat > files/etc/uci-defaults/01-enable-wifi <<'EOF_WIFI'
#!/bin/sh

logger -t enable-wifi "start"

[ -s /etc/config/wireless ] || wifi config || true

uci show wireless 2>/dev/null | grep -q '=wifi-device' || {
    logger -t enable-wifi "no wifi-device found, retry next boot"
    exit 1
}

for dev in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-device/\1/p"); do
    uci -q set "${dev}.disabled=0"
    uci -q set "${dev}.country=CN"

    band="$(uci -q get "${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${dev}.channel=1"
        uci -q set "${dev}.htmode=HE40"
    elif [ "$band" = "5g" ]; then
        uci -q set "${dev}.channel=36"
        uci -q set "${dev}.htmode=HE80"
    fi
done

i=0
for iface in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-iface/\1/p"); do
    uci -q set "${iface}.disabled=0"
    uci -q set "${iface}.mode=ap"
    uci -q set "${iface}.network=lan"

    dev="$(uci -q get "${iface}.device" || true)"
    band="$(uci -q get "wireless.${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2G"
    elif [ "$band" = "5g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5G"
    elif [ "$i" = "0" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2G"
    elif [ "$i" = "1" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5G"
    else
        uci -q set "${iface}.ssid=OpenWrt_WiFi_$i"
    fi

    # 测试阶段默认无密码
    uci -q set "${iface}.encryption=none"
    uci -q delete "${iface}.key"

    i=$((i + 1))
done

uci commit wireless
wifi reload || wifi || true

logger -t enable-wifi "done"
exit 0
EOF_WIFI

chmod +x files/etc/uci-defaults/01-enable-wifi

cat > files/etc/uci-defaults/02-set-argon-theme <<'EOF_ARGON'
#!/bin/sh

logger -t set-argon-theme "set LuCI Argon theme"

uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci

/etc/init.d/uhttpd restart 2>/dev/null || true

logger -t set-argon-theme "done"
exit 0
EOF_ARGON

chmod +x files/etc/uci-defaults/02-set-argon-theme

echo "===== DIY part2 done ====="
