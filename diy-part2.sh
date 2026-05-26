#!/bin/bash
set -e

echo "===== DIY part2: package fixes only; files/ overlay is maintained in repository ====="

# Default LAN IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true

echo "===== Verify part1 packages ====="

if [ ! -f package/luci-theme-argon/Makefile ]; then
    echo "ERROR: luci-theme-argon missing, check diy-part1.sh"
    find package -maxdepth 4 -type d -iname '*argon*' -print || true
    exit 1
fi

if [ ! -f package/lucky/luci-app-lucky/Makefile ]; then
    echo "ERROR: luci-app-lucky missing, check diy-part1.sh"
    find package/lucky -maxdepth 5 -type f -name Makefile | sort || true
    exit 1
fi

if [ ! -f package/lucky/lucky/Makefile ]; then
    echo "ERROR: lucky core package missing, check diy-part1.sh"
    find package/lucky -maxdepth 5 -type f -name Makefile | sort || true
    exit 1
fi

if [ ! -f package/turboacc/luci-app-turboacc/Makefile ]; then
    echo "ERROR: luci-app-turboacc missing, check diy-part1.sh"
    find package/turboacc -maxdepth 6 -type f -name Makefile | sort || true
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

if [ ! -f package/luci-app-eqosplus/Makefile ]; then
    echo "ERROR: luci-app-eqosplus missing, check diy-part1.sh"
    find package -maxdepth 4 -type f -name Makefile | grep -i eqos || true
    exit 1
fi

if grep -q "parent 1:0 protocol all" package/luci-app-eqosplus/root/usr/bin/eqosplus; then
    echo "OK: EQOS Plus MAC IPv6/L2 patch is present"
else
    echo "ERROR: EQOS Plus MAC IPv6/L2 patch missing"
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
find package/luci-app-eqosplus -maxdepth 4 -type f -name Makefile -print || true
find package/luci-app-diskman -maxdepth 3 -type d | sort || true
find package/luci-app-diskman -maxdepth 4 -type f -iname '*.po' | sort || true

echo "===== files/ overlay check ====="
find files -maxdepth 5 -type f | sort || true

echo "===== DIY part2 done ====="
