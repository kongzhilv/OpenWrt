#!/bin/bash
set -e

echo "===== DIY part2: Turbo ACC no-SFE, F2FS fitrw support, clean scripts, force split WiFi SSID ====="

# 默认 IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true

echo "===== Verify part1 packages ====="

if [ ! -f package/luci-theme-argon/Makefile ]; then
    echo "ERROR: luci-theme-argon missing, check diy-part1.sh"
    find package -maxdepth 4 -type d -iname '*argon*' -print || true
    exit 1
fi

if [ ! -f package/lucky/luci-app-lucky/Makefile ]; then
    echo "ERROR: luci-app-lucky missing, check diy-part1.sh"
    find package -maxdepth 5 -type f -name Makefile | grep -i lucky || true
    exit 1
fi

if [ ! -f package/lucky/lucky/Makefile ]; then
    echo "ERROR: lucky core package missing, check diy-part1.sh"
    find package -maxdepth 5 -type f -name Makefile | grep -i lucky || true
    exit 1
fi

if [ ! -f package/turboacc/luci-app-turboacc/Makefile ]; then
    echo "ERROR: luci-app-turboacc missing, check diy-part1.sh"
    find package -maxdepth 6 -type f -name Makefile | grep -i turbo || true
    exit 1
fi

if [ ! -f package/turboacc/nft-fullcone/Makefile ]; then
    echo "ERROR: nft-fullcone missing, check diy-part1.sh"
    find package/turboacc -maxdepth 6 -type f -name Makefile | sort || true
    exit 1
fi

if find package/turboacc -maxdepth 3 -type d -iname '*shortcut*' | grep -q .; then
    echo "ERROR: shortcut-fe exists, but this build must be Turbo ACC no-SFE"
    find package/turboacc -maxdepth 4 -type d -iname '*shortcut*' -print || true
    exit 1
fi

if [ -d package/luci-app-eqosplus ]; then
    echo "ERROR: package/luci-app-eqosplus exists, but this build must not include EQOS Plus"
    find package/luci-app-eqosplus -maxdepth 4 -type f | sort || true
    exit 1
fi

echo "===== Add OpenList source ====="

if [ -d feeds/packages ]; then
    rm -rf feeds/packages/lang/golang
    mkdir -p feeds/packages/lang
    git clone --depth 1 -b 24.x https://github.com/OpenListTeam/packages_lang_golang.git feeds/packages/lang/golang
else
    echo "ERROR: feeds/packages not found after feeds update"
    find feeds -maxdepth 2 -type d 2>/dev/null | sort || true
    exit 1
fi

rm -rf package/openlist
git clone --depth 1 https://github.com/OpenListTeam/OpenList-OpenWRT.git package/openlist

if [ ! -d package/openlist ]; then
    echo "ERROR: package/openlist missing"
    exit 1
fi

echo "===== Add DiskMan source ====="

rm -rf package/luci-app-diskman
rm -rf /tmp/diskman-src-p1a2
rm -rf /tmp/luci-app-diskman-src

git clone --depth 1 https://github.com/lisaac/luci-app-diskman.git /tmp/diskman-src-p1a2

if [ ! -f /tmp/diskman-src-p1a2/applications/luci-app-diskman/Makefile ]; then
    echo "ERROR: DiskMan application Makefile not found"
    find /tmp/diskman-src-p1a2 -maxdepth 5 -type f -name Makefile -print || true
    exit 1
fi

cp -a /tmp/diskman-src-p1a2/applications/luci-app-diskman package/luci-app-diskman
rm -rf /tmp/diskman-src-p1a2
rm -rf /tmp/luci-app-diskman-src

if [ ! -d package/luci-app-diskman ]; then
    echo "ERROR: package/luci-app-diskman missing after copy"
    exit 1
fi

if [ ! -f package/luci-app-diskman/Makefile ]; then
    echo "ERROR: package/luci-app-diskman/Makefile missing after copy"
    find package/luci-app-diskman -maxdepth 5 -type f -print || true
    exit 1
fi

echo "===== Ensure no /tmp/luci-* directories before package install ====="
find /tmp -maxdepth 1 -name 'luci-*' -print -exec rm -rf {} \; 2>/dev/null || true

echo "===== Fix DiskMan LuCI translation dirs ====="

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

echo "===== Stage package tree check ====="
find package/luci-theme-argon -maxdepth 3 -type f -name Makefile -print || true
find package/lucky -maxdepth 3 -type f -name Makefile -print || true
find package/turboacc -maxdepth 4 -type f -name Makefile -print || true
find package/luci-app-diskman -maxdepth 3 -type d | sort || true
find package/luci-app-diskman -maxdepth 4 -type f -iname '*.po' | sort || true

# 只保留真正需要的 uci-defaults 脚本
rm -rf files
mkdir -p files/etc/uci-defaults

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

# Lucky installed but autostart disabled by uci-defaults
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_luci-app-lucky=y

# Turbo ACC no-SFE stable mode
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_NFT_FULLCONE=y
# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE is not set
# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE_CM is not set
# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE_DRV is not set
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-tcp-bbr=y
CONFIG_PACKAGE_kmod-nft-fullcone=y

# EQOS Plus disabled
# CONFIG_PACKAGE_luci-app-eqosplus is not set
# CONFIG_PACKAGE_kmod-ifb is not set
# CONFIG_PACKAGE_tc-tiny is not set
# CONFIG_PACKAGE_bc is not set

# nftables-json may be selected by firewall4/base system, do not treat it as EQOS residue

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
CONFIG_PACKAGE_kmod-fs-ext4=y

# F2FS support required for /dev/fitrw persistent overlay
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_f2fsck=y
CONFIG_PACKAGE_mkf2fs=y

CONFIG_PACKAGE_mount-utils=y
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

# Still disabled
# CONFIG_PACKAGE_rpcd-mod-file is not set
# CONFIG_PACKAGE_luci-app-argon-config is not set
# CONFIG_PACKAGE_kmod-usb-storage is not set
# CONFIG_PACKAGE_kmod-usb-storage-uas is not set
# CONFIG_PACKAGE_block-mount is not set
# CONFIG_PACKAGE_btrfs-progs is not set
# CONFIG_PACKAGE_kmod-fs-btrfs is not set
# CONFIG_PACKAGE_kmod-fs-exfat is not set
# CONFIG_PACKAGE_kmod-fs-msdos is not set
# CONFIG_PACKAGE_kmod-fs-ntfs3 is not set
# CONFIG_PACKAGE_kmod-fs-vfat is not set
# CONFIG_PACKAGE_dosfstools is not set
# CONFIG_PACKAGE_exfat-fsck is not set
# CONFIG_PACKAGE_exfat-mkfs is not set
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
# CONFIG_PACKAGE_dockerd is not set
# CONFIG_PACKAGE_docker-compose is not set
# CONFIG_PACKAGE_luci-app-dockerman is not set
EOF_CONFIG

cat > files/etc/uci-defaults/01-enable-wifi <<'EOF_WIFI'
#!/bin/sh

logger -t enable-wifi "start force split SSID"

[ -s /etc/config/wireless ] || wifi config || true

uci show wireless 2>/dev/null | grep -q '=wifi-device' || {
    logger -t enable-wifi "no wifi-device found, retry next boot"
    exit 1
}

for dev in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-device/\1/p"); do
    uci -q set "${dev}.disabled=0"

    if [ -z "$(uci -q get "${dev}.country" 2>/dev/null)" ]; then
        uci -q set "${dev}.country=CN"
    fi

    band="$(uci -q get "${dev}.band" || true)"

    if [ -z "$(uci -q get "${dev}.channel" 2>/dev/null)" ]; then
        if [ "$band" = "2g" ]; then
            uci -q set "${dev}.channel=1"
        elif [ "$band" = "5g" ]; then
            uci -q set "${dev}.channel=36"
        fi
    fi

    if [ -z "$(uci -q get "${dev}.htmode" 2>/dev/null)" ]; then
        if [ "$band" = "2g" ]; then
            uci -q set "${dev}.htmode=HE40"
        elif [ "$band" = "5g" ]; then
            uci -q set "${dev}.htmode=HE80"
        fi
    fi
done

i=0
for iface in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-iface/\1/p"); do
    uci -q set "${iface}.disabled=0"
    uci -q set "${iface}.mode=ap"

    if [ -z "$(uci -q get "${iface}.network" 2>/dev/null)" ]; then
        uci -q set "${iface}.network=lan"
    fi

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

    if [ -z "$(uci -q get "${iface}.encryption" 2>/dev/null)" ]; then
        uci -q set "${iface}.encryption=none"
    fi

    i=$((i + 1))
done

uci commit wireless
wifi reload || wifi || true

logger -t enable-wifi "done force split SSID"
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

cat > files/etc/uci-defaults/03-disable-lucky-autostart <<'EOF_LUCKY_DISABLE'
#!/bin/sh

logger -t disable-lucky-autostart "disable lucky autostart for F50 hardboot test"

if [ -x /etc/init.d/lucky ]; then
    /etc/init.d/lucky stop 2>/dev/null || true
    /etc/init.d/lucky disable 2>/dev/null || true
fi

rm -f /etc/rc.d/S*lucky /etc/rc.d/K*lucky 2>/dev/null || true

logger -t disable-lucky-autostart "done"
exit 0
EOF_LUCKY_DISABLE

chmod +x files/etc/uci-defaults/03-disable-lucky-autostart

cat > files/etc/uci-defaults/04-config-turboacc <<'EOF_TURBOACC'
#!/bin/sh

logger -t config-turboacc "configure Turbo ACC no-SFE stable mode"

uci -q set turboacc.config.sw_flow='1'
uci -q set turboacc.config.hw_flow='1'
uci -q set turboacc.config.sfe_flow='0'
uci -q set turboacc.config.fullcone_nat='1'
uci -q set turboacc.config.fullcone6='0'
uci -q set turboacc.config.hw_wed='0'
uci -q set turboacc.config.bbr_cca='1'
uci -q commit turboacc

uci -q set firewall.@defaults[0].flow_offloading='1'
uci -q set firewall.@defaults[0].flow_offloading_hw='1'
uci -q commit firewall

/etc/init.d/firewall restart 2>/dev/null || true

logger -t config-turboacc "done"
exit 0
EOF_TURBOACC

chmod +x files/etc/uci-defaults/04-config-turboacc

echo "===== DIY part2 done ====="
