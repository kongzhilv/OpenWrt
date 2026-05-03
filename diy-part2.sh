#!/bin/bash
set -e

echo "===== DIY part2: RAX3000M F50 WiFi SFTP ttyd Argon OpenList DiskMan + USB storage + all temperatures ====="

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
rm -rf package/luci-app-diskman
git clone --depth 1 https://github.com/lisaac/luci-app-diskman.git package/luci-app-diskman

# 清掉旧 files，避免旧 F50/extroot/OpenClash 脚本进入固件
rm -rf files
mkdir -p files/etc/uci-defaults
mkdir -p files/sbin
mkdir -p files/usr/share/rpcd/acl.d
mkdir -p files/www/luci-static/resources/view/status/include

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
CONFIG_PACKAGE_rpcd-mod-file=y

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

# DiskMan, no extroot scripts
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_partx-utils=y
CONFIG_PACKAGE_losetup=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_smartmontools=y

# USB storage/ext4 test step, still no extroot script
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_kmod-lib-crc16=y
CONFIG_PACKAGE_mount-utils=y

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

# USB / F50
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

# Not enabled in this step
# CONFIG_PACKAGE_luci-app-argon-config is not set
# CONFIG_PACKAGE_btrfs-progs is not set
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

# Still disabled
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

cat > files/sbin/tempinfo <<'EOF_TEMPINFO'
#!/bin/sh

json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

emit_temp() {
    local name="$1"
    local path="$2"
    local raw="$3"
    local src="$4"

    case "$raw" in
        ''|*[!0-9-]*) return ;;
    esac

    # Linux thermal and hwmon temp*_input values are normally millidegree Celsius.
    local celsius
    celsius="$(awk -v t="$raw" 'BEGIN { printf "%.1f", t / 1000 }')"

    local ename epath esrc
    ename="$(printf '%s' "$name" | json_escape)"
    epath="$(printf '%s' "$path" | json_escape)"
    esrc="$(printf '%s' "$src" | json_escape)"

    [ "$first" = 0 ] && printf ',\n'
    first=0

    printf '    {"name":"%s","path":"%s","source":"%s","raw":%s,"celsius":%s}' \
        "$ename" "$epath" "$esrc" "$raw" "$celsius"
}

first=1
printf '{"temps":[\n'

# Generic Linux thermal zones: CPU, SoC, WiFi, board sensors, etc. when exposed by kernel.
for z in /sys/class/thermal/thermal_zone*; do
    [ -r "$z/temp" ] || continue
    raw="$(cat "$z/temp" 2>/dev/null | tr -d '[:space:]')"
    type="$(cat "$z/type" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$type" ] || type="$(basename "$z")"
    emit_temp "$type" "$z/temp" "$raw" "thermal"
done

# Generic hwmon sensors. Some WiFi, switch, PMIC or board sensors may appear here.
for h in /sys/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    chip="$(cat "$h/name" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$chip" ] || chip="$(basename "$h")"

    for t in "$h"/temp*_input; do
        [ -r "$t" ] || continue
        raw="$(cat "$t" 2>/dev/null | tr -d '[:space:]')"
        idx="$(basename "$t" | sed 's/^temp//;s/_input$//')"
        label="$(cat "$h/temp${idx}_label" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -n "$label" ] || label="temp${idx}"
        emit_temp "${chip} ${label}" "$t" "$raw" "hwmon"
    done
done

# mt76 debugfs WiFi temperature paths, if debugfs is mounted and the driver exposes them.
for p in /sys/kernel/debug/ieee80211/phy*/mt76/temperature /sys/kernel/debug/ieee80211/phy*/mt76/temp; do
    [ -r "$p" ] || continue
    raw_text="$(cat "$p" 2>/dev/null | tr -d '\r')"
    raw="$(printf '%s' "$raw_text" | grep -Eo -- '-?[0-9]+' | head -n 1)"
    [ -n "$raw" ] || continue

    # Some debugfs values may be Celsius instead of millidegree. Normalize small values.
    if [ "$raw" -gt -200 ] 2>/dev/null && [ "$raw" -lt 200 ] 2>/dev/null; then
        raw=$((raw * 1000))
    fi

    phy="$(printf '%s' "$p" | sed -n 's#.*/\(phy[0-9][0-9]*\)/.*#\1#p')"
    [ -n "$phy" ] || phy="WiFi"
    emit_temp "${phy} WiFi" "$p" "$raw" "mt76-debugfs"
done

printf '\n]}\n'
EOF_TEMPINFO

chmod +x files/sbin/tempinfo

cat > files/usr/share/rpcd/acl.d/luci-app-tempinfo.json <<'EOF_TEMPINFO_ACL'
{
  "luci-app-tempinfo": {
    "description": "Grant LuCI access to readable system temperature sensors",
    "read": {
      "ubus": {
        "file": [ "exec" ]
      },
      "file": {
        "/sbin/tempinfo": [ "exec" ]
      }
    }
  }
}
EOF_TEMPINFO_ACL

cat > files/www/luci-static/resources/view/status/include/11_all_temperatures.js <<'EOF_TEMPINFO_JS'
'use strict';
'require baseclass';
'require fs';
'require poll';

function formatTemp(t) {
	var n = Number(t);
	return isNaN(n) ? '?' : n.toFixed(1) + ' °C';
}

function renderRows(data) {
	var temps = (data && Array.isArray(data.temps)) ? data.temps : [];

	if (!temps.length) {
		return E('em', _('No readable temperature sensors found.'));
	}

	var rows = temps.map(function(t) {
		return E('div', { 'class': 'tr' }, [
			E('div', { 'class': 'td left' }, [ t.name || _('Unknown') ]),
			E('div', { 'class': 'td left' }, [ formatTemp(t.celsius) ]),
			E('div', { 'class': 'td left' }, [ t.source || '-' ])
		]);
	});

	return E('div', { 'class': 'table' }, [
		E('div', { 'class': 'tr table-titles' }, [
			E('div', { 'class': 'th left' }, _('Sensor')),
			E('div', { 'class': 'th left' }, _('Temperature')),
			E('div', { 'class': 'th left' }, _('Source'))
		]),
		rows
	]);
}

return baseclass.extend({
	title: _('Temperatures'),

	load: function() {
		return fs.exec_direct('/sbin/tempinfo', [ 'json' ], 'json').catch(function() {
			return { temps: [] };
		});
	},

	render: function(data) {
		poll.add(L.bind(function() {
			return fs.exec_direct('/sbin/tempinfo', [ 'json' ], 'json').then(L.bind(function(newdata) {
				var node = document.getElementById('all-temperatures-table');
				if (node)
					node.replaceChildren(renderRows(newdata));
			}, this)).catch(function() {});
		}, this), 5);

		return E('div', { 'class': 'cbi-section' }, [
			E('h3', _('Temperatures')),
			E('div', { 'id': 'all-temperatures-table' }, [ renderRows(data) ])
		]);
	}
});
EOF_TEMPINFO_JS

echo "===== DIY part2 done ====="
