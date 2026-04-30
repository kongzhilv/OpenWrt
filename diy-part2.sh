#!/bin/bash
# 描述: 官方 OpenWrt + GitHub Actions 稳定自定义脚本
# 目标:
# - 合并仓库根目录 files/ 到 openwrt/files/
# - 默认 IP: 192.168.2.1
# - 默认中文 + Argon 主题
# - 默认开启无密码开放 WiFi
# - 5G 默认固定 36 信道 + HE80，避免 auto/HE160/DFS 导致 5G 看起来被禁用
# - 温度显示: luci-app-temp-status
# - DiskMan: luci-app-diskman
# - 网页终端: luci-app-ttyd
# - OpenList: OpenListTeam/OpenList-OpenWRT
# - Turbo ACC: luci-app-turboacc
# - eMMC extroot: 首次启动自动切换到 mmcblk0p6，目标约 1GiB overlay
# - F50 USB 网卡: 不再 reset xHCI，不再 guardian 常驻；改为出现后按 MAC 绑定 + USB authorized 轻量刷新
#
# 注意:
# - 本脚本不内置 factory 文件
# - 本脚本不自动写 /dev/mmcblk0p2
# - 适用于 factory 已经手动修好的 RAX3000M
# - extroot 首次初始化默认格式化 /dev/mmcblk0p6，避免旧 overlay / 旧密码 / 旧脚本复活
# - 不集成 ipheth/usbmuxd/libimobiledevice/usb-modeswitch，排除它们对 F50 冷启动枚举的干扰

set -e

echo "===== 开始执行 diy-part2.sh ====="

# 0. 合并仓库根目录 files/ 到 openwrt/files/
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
rm -rf package/openlist 2>/dev/null || true
git clone --depth=1 https://github.com/OpenListTeam/OpenList-OpenWRT package/openlist

# 4. 接入 Turbo ACC
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
        luci-app-turboacc kmod-nft-offload \
        apk-mbedtls uclient-fetch ca-bundle ca-certificates \
        block-mount e2fsprogs parted blkid kmod-fs-ext4 \
        kmod-usb-net kmod-usb-net-rndis kmod-usb-net-cdc-ether \
        kmod-usb-net-cdc-eem kmod-usb-net-cdc-subset \
        kmod-usb-net-cdc-ncm kmod-usb-net-huawei-cdc-ncm \
        kmod-usb-net-cdc-mbim kmod-usb-net-qmi-wwan kmod-usb-wdm \
        kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179 \
        kmod-usb-net-aqc111 kmod-usb-net-lan78xx kmod-usb-net-smsc95xx \
        kmod-usb-net-ipheth usbmuxd libimobiledevice usbutils usb-modeswitch \
        kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan kmod-usb-acm \
    ; do
        sed -i "/^CONFIG_PACKAGE_${p}=/d" .config
        sed -i "/^# CONFIG_PACKAGE_${p} is not set/d" .config
    done

    cat >> .config <<'EOF_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y

# 禁用冲突包
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_luci-app-adguardhome is not set
# CONFIG_PACKAGE_openlist2 is not set
# CONFIG_PACKAGE_luci-app-openlist2 is not set

# OpenWrt 25.12 apk 包管理和 HTTPS 源
CONFIG_PACKAGE_apk-mbedtls=y
CONFIG_PACKAGE_uclient-fetch=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ca-certificates=y

# OpenList
CONFIG_PACKAGE_openlist=y
CONFIG_PACKAGE_luci-app-openlist=y
CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=y

# DiskMan / 温度 / ttyd
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-app-temp-status=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y

# Argon 配置
CONFIG_PACKAGE_luci-app-argon-config=y

# Turbo ACC
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_kmod-nft-offload=y

# eMMC extroot 必需
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_kmod-fs-ext4=y

# USB 网络基础
CONFIG_PACKAGE_kmod-usb-net=y

# F50 / RNDIS / CDC Ethernet
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y

# NCM / MBIM / QMI 4G/5G 网卡常用
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-wdm=y

# USB 转千兆网卡常见芯片
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
CONFIG_PACKAGE_kmod-usb-net-asix=y
CONFIG_PACKAGE_kmod-usb-net-asix-ax88179=y
CONFIG_PACKAGE_kmod-usb-net-aqc111=y
CONFIG_PACKAGE_kmod-usb-net-lan78xx=y
CONFIG_PACKAGE_kmod-usb-net-smsc95xx=y

# 不再集成 iPhone/usbmuxd/usb-modeswitch，排除对 F50 冷启动枚举的干扰
# CONFIG_PACKAGE_kmod-usb-net-ipheth is not set
# CONFIG_PACKAGE_usbmuxd is not set
# CONFIG_PACKAGE_libimobiledevice is not set
# CONFIG_PACKAGE_usb-modeswitch is not set

CONFIG_PACKAGE_usbutils=y

# USB 串口，给 4G/5G 模块备用
CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-usb-serial-wwan=y
CONFIG_PACKAGE_kmod-usb-acm=y
EOF_CONFIG
fi

# 9. 首次开机基础设置
echo ">>> 写入首次开机基础设置"
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/sysctl.d
mkdir -p files/usr/sbin
mkdir -p files/etc/init.d
mkdir -p files/etc/hotplug.d/net
mkdir -p files/etc/hotplug.d/usb

# 清理旧名称，避免 files/ 里残留旧脚本导致执行顺序错误
rm -f files/etc/uci-defaults/05-emmc-extroot 2>/dev/null || true
rm -f files/etc/uci-defaults/97-enable-wifi 2>/dev/null || true

# 清理旧 F50 修复/守护脚本
rm -f files/usr/sbin/f50-usb-fix 2>/dev/null || true
rm -f files/usr/sbin/f50-usb-guardian 2>/dev/null || true
rm -f files/etc/init.d/f50-usb-fix 2>/dev/null || true
rm -f files/etc/init.d/f50-usb-guardian 2>/dev/null || true
rm -f files/etc/uci-defaults/96-enable-f50-usb-fix 2>/dev/null || true
rm -f files/etc/uci-defaults/96-enable-f50-usb-guardian 2>/dev/null || true
rm -f files/etc/hotplug.d/net/20-f50-usb-fix 2>/dev/null || true
rm -f files/etc/hotplug.d/net/20-f50-usb-guardian 2>/dev/null || true
rm -f files/etc/hotplug.d/usb/20-f50-usb-fix 2>/dev/null || true
rm -f files/etc/hotplug.d/usb/20-f50-usb-guardian 2>/dev/null || true
rm -f files/etc/preinit.d/03-f50-vbus-cycle 2>/dev/null || true

cat << 'EOF_UCI' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF_UCI

# 9.1 首次开机：默认开启无密码 WiFi
echo ">>> 写入首次开机 WiFi 默认开启配置，无密码开放网络，5G 固定 36 + HE80"
cat << 'EOF_WIFI' > files/etc/uci-defaults/01-enable-wifi
#!/bin/sh

logger -t enable-wifi "start enable wifi uci-defaults script"

[ -s /etc/config/wireless ] || wifi config || true

uci show wireless 2>/dev/null | grep -q '=wifi-device' || {
    logger -t enable-wifi "no wifi-device found, keep script for next boot"
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
    uci -q set "${iface}.encryption=none"
    uci -q delete "${iface}.key"

    dev="$(uci -q get "${iface}.device" || true)"
    band="$(uci -q get "wireless.${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2"
    elif [ "$band" = "5g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5"
    elif [ "$i" = "0" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2"
    elif [ "$i" = "1" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5"
    else
        uci -q set "${iface}.ssid=OpenWrt-WiFi-$i"
    fi

    i=$((i + 1))
done

uci commit wireless
logger -t enable-wifi "wifi config written successfully"
exit 0
EOF_WIFI

# 9.2 F50 USB 网卡：只绑定，不 reset xHCI
echo ">>> 写入 F50 绑定脚本：不再 reset xHCI，只做 MAC 绑定和 authorized 轻量刷新"
cat << 'EOF_F50_BIND' > files/usr/sbin/f50-bind
#!/bin/sh

TAG="f50-bind"
F50_MAC="${F50_MAC:-b8:d4:bc:9f:37:bd}"
LOCKFILE="/tmp/f50-bind.lock"

log() {
    logger -t "$TAG" "$*"
    echo "$TAG: $*"
}

lock_me() {
    if command -v lock >/dev/null 2>&1; then
        lock -n "$LOCKFILE" || exit 0
    fi
}

unlock_me() {
    if command -v lock >/dev/null 2>&1; then
        lock -u "$LOCKFILE" || true
    fi
}

bad_dev() {
    case "$1" in
        lo|eth0|eth1|lan1|lan2|lan3|br-lan|docker0|phy0-ap0|phy1-ap0|phy0-sta0|phy1-sta0)
            return 0
        ;;
    esac
    return 1
}

find_f50_dev() {
    for n in /sys/class/net/*; do
        dev="$(basename "$n")"
        bad_dev "$dev" && continue

        mac="$(cat "$n/address" 2>/dev/null || true)"
        [ "$mac" = "$F50_MAC" ] && {
            echo "$dev"
            return 0
        }
    done

    return 1
}

usb_seen_by_sysfs() {
    for d in /sys/bus/usb/devices/*; do
        [ -f "$d/idVendor" ] || continue
        [ -f "$d/idProduct" ] || continue

        v="$(cat "$d/idVendor" 2>/dev/null || true)"
        p="$(cat "$d/idProduct" 2>/dev/null || true)"

        if [ "$v" = "19d2" ] && { [ "$p" = "1353" ] || [ "$p" = "1352" ]; }; then
            return 0
        fi
    done

    return 1
}

usb_seen_by_lsusb() {
    command -v lsusb >/dev/null 2>&1 || return 1
    lsusb 2>/dev/null | grep -Eiq '19d2:1353|19d2:1352|Unisoc F50'
}

usb_seen() {
    usb_seen_by_sysfs || usb_seen_by_lsusb
}

disable_usb_autosuspend_once() {
    echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

    for f in /sys/bus/usb/devices/*/power/control; do
        [ -e "$f" ] && echo on > "$f" 2>/dev/null || true
    done

    for f in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
        [ -e "$f" ] && echo -1 > "$f" 2>/dev/null || true
    done
}

refresh_usb_authorized_once() {
    refreshed=0

    log "F50 visible on USB bus but no netdev, try authorized refresh"

    for d in /sys/bus/usb/devices/*; do
        [ -f "$d/idVendor" ] || continue
        [ -f "$d/idProduct" ] || continue

        v="$(cat "$d/idVendor" 2>/dev/null || true)"
        p="$(cat "$d/idProduct" 2>/dev/null || true)"

        if [ "$v" = "19d2" ] && { [ "$p" = "1353" ] || [ "$p" = "1352" ]; }; then
            if [ -w "$d/authorized" ]; then
                log "toggle authorized on $d"
                echo 0 > "$d/authorized" 2>/dev/null || true
                sleep 3
                echo 1 > "$d/authorized" 2>/dev/null || true
                refreshed=1
            fi
        fi
    done

    if [ "$refreshed" = "0" ]; then
        # 你的机器实测 toggle usb2/authorized 会让 F50 重新枚举。
        # 这里只在“F50 已经出现在 USB 总线但没有 netdev”时执行，不做 xHCI unbind/bind。
        for a in /sys/bus/usb/devices/usb2/authorized /sys/bus/usb/devices/usb1/authorized; do
            if [ -w "$a" ]; then
                log "toggle root hub authorized $a"
                echo 0 > "$a" 2>/dev/null || true
                sleep 3
                echo 1 > "$a" 2>/dev/null || true
                refreshed=1
                break
            fi
        done
    fi

    sleep 15
}

bind_network() {
    dev="$(find_f50_dev || true)"

    [ -n "$dev" ] || {
        return 1
    }

    log "F50 found netdev=$dev mac=$F50_MAC"

    uci -q delete network.F50
    uci -q delete network.F50_v6

    uci set network.F50='interface'
    uci set network.F50.proto='dhcp'
    uci set network.F50.device="$dev"
    uci set network.F50.multipath='off'

    uci set network.F50_v6='interface'
    uci set network.F50_v6.proto='dhcpv6'
    uci set network.F50_v6.device="$dev"
    uci set network.F50_v6.reqaddress='try'
    uci set network.F50_v6.reqprefix='auto'
    uci set network.F50_v6.norelease='1'
    uci set network.F50_v6.multipath='off'

    uci commit network

    ifup F50 2>/dev/null || true
    ifup F50_v6 2>/dev/null || true

    log "F50 bound to $dev"
    return 0
}

wait_and_bind() {
    disable_usb_autosuspend_once

    i=0
    while [ "$i" -lt 45 ]; do
        if bind_network; then
            exit 0
        fi
        i=$((i + 1))
        sleep 2
    done

    if usb_seen; then
        refresh_usb_authorized_once

        i=0
        while [ "$i" -lt 45 ]; do
            if bind_network; then
                exit 0
            fi
            i=$((i + 1))
            sleep 2
        done

        log "F50 USB device visible, but CDC netdev still not created"
        exit 1
    fi

    log "F50 not found on USB bus"
    exit 1
}

case "${1:-start}" in
    start|bind)
        lock_me
        trap unlock_me EXIT
        wait_and_bind
    ;;
    refresh)
        lock_me
        trap unlock_me EXIT
        disable_usb_autosuspend_once
        refresh_usb_authorized_once
        bind_network || exit 1
    ;;
    *)
        echo "Usage: $0 {start|bind|refresh}"
        exit 1
    ;;
esac

exit 0
EOF_F50_BIND

chmod +x files/usr/sbin/f50-bind

cat << 'EOF_F50_INITD' > files/etc/init.d/f50-bind
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    (
        sleep 20
        /usr/sbin/f50-bind start
    ) &
}
EOF_F50_INITD

chmod +x files/etc/init.d/f50-bind

cat << 'EOF_F50_HOTPLUG_USB' > files/etc/hotplug.d/usb/20-f50-bind
#!/bin/sh

case "$ACTION" in
    add|bind) ;;
    *) exit 0 ;;
esac

case "$PRODUCT" in
    19d2/1353/*|19d2/1352/*|19d2/*)
        (
            sleep 8
            /usr/sbin/f50-bind bind
        ) &
    ;;
esac

exit 0
EOF_F50_HOTPLUG_USB

chmod +x files/etc/hotplug.d/usb/20-f50-bind

cat << 'EOF_F50_HOTPLUG_NET' > files/etc/hotplug.d/net/20-f50-bind
#!/bin/sh

[ "$ACTION" = "add" ] || exit 0

(
    sleep 5
    /usr/sbin/f50-bind bind
) &

exit 0
EOF_F50_HOTPLUG_NET

chmod +x files/etc/hotplug.d/net/20-f50-bind

# 9.3 USB 禁用 autosuspend
cat << 'EOF_USB_NO_AUTOSUSPEND' > files/etc/init.d/usb-no-autosuspend
#!/bin/sh /etc/rc.common

START=20

start() {
    echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

    for f in /sys/bus/usb/devices/*/power/control; do
        [ -e "$f" ] && echo on > "$f" 2>/dev/null || true
    done

    for f in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
        [ -e "$f" ] && echo -1 > "$f" 2>/dev/null || true
    done
}
EOF_USB_NO_AUTOSUSPEND

chmod +x files/etc/init.d/usb-no-autosuspend

cat << 'EOF_USB_NO_AUTOSUSPEND_HOTPLUG' > files/etc/hotplug.d/usb/21-usb-no-autosuspend
#!/bin/sh

case "$ACTION" in
    add|bind) ;;
    *) exit 0 ;;
esac

(
    sleep 2
    for f in /sys/bus/usb/devices/*/power/control; do
        [ -e "$f" ] && echo on > "$f" 2>/dev/null || true
    done
    for f in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
        [ -e "$f" ] && echo -1 > "$f" 2>/dev/null || true
    done
) &

exit 0
EOF_USB_NO_AUTOSUSPEND_HOTPLUG

chmod +x files/etc/hotplug.d/usb/21-usb-no-autosuspend

cat << 'EOF_F50_ENABLE' > files/etc/uci-defaults/96-f50-services
#!/bin/sh

/etc/init.d/f50-usb-fix stop 2>/dev/null || true
/etc/init.d/f50-usb-fix disable 2>/dev/null || true
/etc/init.d/f50-usb-guardian stop 2>/dev/null || true
/etc/init.d/f50-usb-guardian disable 2>/dev/null || true

/etc/init.d/usbmuxd stop 2>/dev/null || true
/etc/init.d/usbmuxd disable 2>/dev/null || true

/etc/init.d/usb-no-autosuspend enable 2>/dev/null || true
/etc/init.d/f50-bind enable 2>/dev/null || true

exit 0
EOF_F50_ENABLE

chmod +x files/etc/uci-defaults/96-f50-services

# 10. BBR 默认配置
echo ">>> 写入 BBR 默认配置"
cat << 'EOF_BBR' > files/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF_BBR

cat << 'EOF_NET' > files/etc/uci-defaults/98-network-optimize
#!/bin/sh
uci -q set network.globals.packet_steering='1'
uci commit network

uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

exit 0
EOF_NET

# 11. 独立 extroot 修复命令
echo ">>> 写入 /usr/sbin/emmc-extroot-setup"
cat << 'EOF_EXTROOT_BIN' > files/usr/sbin/emmc-extroot-setup
#!/bin/sh
set -eu

LOGTAG="emmc-extroot"
LOGFILE="/tmp/emmc-extroot.log"
CLEAN_EXTROOT="${CLEAN_EXTROOT:-1}"

log() {
    echo "$LOGTAG: $*" | tee -a "$LOGFILE"
    logger -t "$LOGTAG" "$*"
}

[ -b /dev/mmcblk0 ] || {
    log "/dev/mmcblk0 not found"
    exit 0
}

mkdir -p /mnt/extroot /mnt/data

if mount | grep -q '^/dev/mmcblk0p6 on /overlay '; then
    log "extroot already active"
    exit 0
fi

command -v parted >/dev/null 2>&1 || {
    log "parted missing"
    exit 1
}

command -v mkfs.ext4 >/dev/null 2>&1 || {
    log "mkfs.ext4 missing"
    exit 1
}

command -v blkid >/dev/null 2>&1 || {
    log "blkid missing"
    exit 1
}

[ -x /sbin/block ] || {
    log "/sbin/block missing"
    exit 1
}

umount /mnt/extroot 2>/dev/null || true
umount /mnt/data 2>/dev/null || true

if [ ! -b /dev/mmcblk0p6 ] || [ ! -b /dev/mmcblk0p7 ]; then
    log "repartitioning /dev/mmcblk0: p6=1GiB extroot, p7=rest data"
    parted -s /dev/mmcblk0 rm 7 || true
    parted -s /dev/mmcblk0 rm 6 || true
    parted -s /dev/mmcblk0 mkpart primary ext4 512MiB 1536MiB
    parted -s /dev/mmcblk0 name 6 extroot
    parted -s /dev/mmcblk0 mkpart primary ext4 1536MiB 100%
    parted -s /dev/mmcblk0 name 7 data
    partprobe /dev/mmcblk0 || true
    sleep 3
fi

[ -b /dev/mmcblk0p6 ] || {
    log "/dev/mmcblk0p6 not found"
    exit 1
}

[ -b /dev/mmcblk0p7 ] || {
    log "/dev/mmcblk0p7 not found"
    exit 1
}

if [ "$CLEAN_EXTROOT" = "1" ]; then
    if ! mount -t ext4 /dev/mmcblk0p6 /mnt/extroot 2>/dev/null; then
        log "formatting /dev/mmcblk0p6 as ext4"
        mkfs.ext4 -F -L extroot /dev/mmcblk0p6
        mount -t ext4 /dev/mmcblk0p6 /mnt/extroot
    elif [ ! -e /mnt/extroot/etc/.extroot_emmc_done ]; then
        log "clean extroot enabled, formatting /dev/mmcblk0p6 to remove stale overlay"
        umount /mnt/extroot
        mkfs.ext4 -F -L extroot /dev/mmcblk0p6
        mount -t ext4 /dev/mmcblk0p6 /mnt/extroot
    else
        log "extroot partition already prepared"
    fi
else
    if ! mount -t ext4 /dev/mmcblk0p6 /mnt/extroot 2>/dev/null; then
        log "formatting /dev/mmcblk0p6 as ext4"
        mkfs.ext4 -F -L extroot /dev/mmcblk0p6
        mount -t ext4 /dev/mmcblk0p6 /mnt/extroot
    fi
fi

if ! block info /dev/mmcblk0p7 | grep -q 'TYPE="ext4"'; then
    log "formatting /dev/mmcblk0p7 as ext4"
    mkfs.ext4 -F -L data /dev/mmcblk0p7
fi

mount -t ext4 /dev/mmcblk0p7 /mnt/data 2>/dev/null || true

EXTROOT_UUID="$(blkid -s UUID -o value /dev/mmcblk0p6)"
DATA_UUID="$(blkid -s UUID -o value /dev/mmcblk0p7)"

[ -n "$EXTROOT_UUID" ] || {
    log "failed to get extroot UUID"
    exit 1
}

[ -n "$DATA_UUID" ] || {
    log "failed to get data UUID"
    exit 1
}

log "copy current overlay to /dev/mmcblk0p6"
mkdir -p /mnt/extroot
tar -C /overlay -cpf - . | tar -C /mnt/extroot -xpf -

mkdir -p /mnt/extroot/etc/config

log "writing /etc/config/fstab"
cat > /etc/config/fstab <<EOF_FSTAB
config global
        option anon_swap '0'
        option anon_mount '0'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '1'

config mount 'extroot'
        option target '/overlay'
        option uuid '$EXTROOT_UUID'
        option fstype 'ext4'
        option enabled '1'
        option enabled_fsck '1'

config mount 'data'
        option target '/mnt/data'
        option uuid '$DATA_UUID'
        option fstype 'ext4'
        option enabled '1'
        option enabled_fsck '1'
EOF_FSTAB

cp -f /etc/config/fstab /mnt/extroot/etc/config/fstab
mkdir -p /mnt/extroot/etc
: > /mnt/extroot/etc/.extroot_emmc_done

sync

umount /mnt/data 2>/dev/null || true
umount /mnt/extroot 2>/dev/null || true

log "extroot prepared, rebooting"
reboot
exit 0
EOF_EXTROOT_BIN

chmod +x files/usr/sbin/emmc-extroot-setup

# 12. 首次启动自动执行 extroot
cat << 'EOF_EXTROOT_UCI' > files/etc/uci-defaults/99-emmc-extroot
#!/bin/sh
logger -t emmc-extroot "start extroot uci-defaults script"
/usr/sbin/emmc-extroot-setup
exit 0
EOF_EXTROOT_UCI

# 13. 脚本权限
chmod +x files/etc/uci-defaults/01-enable-wifi
chmod +x files/etc/uci-defaults/96-f50-services
chmod +x files/etc/uci-defaults/98-network-optimize
chmod +x files/etc/uci-defaults/99-custom-setup
chmod +x files/etc/uci-defaults/99-emmc-extroot

chmod +x files/usr/sbin/f50-bind
chmod +x files/usr/sbin/emmc-extroot-setup

chmod +x files/etc/init.d/f50-bind
chmod +x files/etc/init.d/usb-no-autosuspend

chmod +x files/etc/hotplug.d/net/20-f50-bind
chmod +x files/etc/hotplug.d/usb/20-f50-bind
chmod +x files/etc/hotplug.d/usb/21-usb-no-autosuspend

# 14. Rust / CI 兼容性修复
echo ">>> 修复 Rust 在 GitHub Actions / CI 下的 host 编译问题"
if [ -f feeds/packages/lang/rust/Makefile ]; then
    sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

echo "===== diy-part2.sh 执行完成 ====="
