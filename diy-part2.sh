#!/bin/bash
set -e

echo "===== DIY part2: RAX3000M F50 WiFi SFTP ttyd Argon OpenList DiskMan USB storage TempInfo + manual extroot scripts ====="

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
mkdir -p files/usr/sbin
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

# DiskMan, no auto extroot
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

# USB storage/ext4 test step, still no auto extroot
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

cat > files/etc/uci-defaults/03-argon-dark-line-fix <<'EOF_ARGON_CSS'
#!/bin/sh

logger -t argon-dark-line-fix "patch Argon dark table borders"

MARK='/* custom-argon-dark-line-fix */'
for css in /www/luci-static/argon/css/*.css /www/luci-static/argon/*.css; do
    [ -f "$css" ] || continue
    grep -q 'custom-argon-dark-line-fix' "$css" 2>/dev/null && continue
    cat >> "$css" <<'EOF_CSS'
/* custom-argon-dark-line-fix */
@media (prefers-color-scheme: dark) {
  .cbi-section table.table,
  .cbi-section .table,
  table.table,
  .table {
    border-color: rgba(255,255,255,.08) !important;
  }
  .cbi-section table.table tr,
  .cbi-section table.table tr.tr,
  .cbi-section .table .tr,
  table.table tr,
  table.table tr.tr,
  .table .tr,
  .td,
  .th {
    border-color: rgba(255,255,255,.08) !important;
    box-shadow: none !important;
  }
}
[data-theme="dark"] .cbi-section table.table,
[data-theme="dark"] .cbi-section .table,
[data-theme="dark"] table.table,
[data-theme="dark"] .table,
.dark .cbi-section table.table,
.dark .cbi-section .table,
.dark table.table,
.dark .table {
  border-color: rgba(255,255,255,.08) !important;
}
[data-theme="dark"] .cbi-section table.table tr,
[data-theme="dark"] .cbi-section table.table tr.tr,
[data-theme="dark"] .cbi-section .table .tr,
[data-theme="dark"] table.table tr,
[data-theme="dark"] table.table tr.tr,
[data-theme="dark"] .table .tr,
[data-theme="dark"] .td,
[data-theme="dark"] .th,
.dark .cbi-section table.table tr,
.dark .cbi-section table.table tr.tr,
.dark .cbi-section .table .tr,
.dark table.table tr,
.dark table.table tr.tr,
.dark .table .tr,
.dark .td,
.dark .th {
  border-color: rgba(255,255,255,.08) !important;
  box-shadow: none !important;
}
EOF_CSS
done

rm -rf /tmp/luci-* /tmp/luci-indexcache 2>/dev/null || true
logger -t argon-dark-line-fix "done"
exit 0
EOF_ARGON_CSS

chmod +x files/etc/uci-defaults/03-argon-dark-line-fix

cat > files/sbin/tempinfo <<'EOF_TEMPINFO'
#!/bin/sh

MODE="${1:-summary}"

json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

norm_c() {
    awk -v t="$1" 'BEGIN { printf "%.1f", t / 1000 }'
}

first=1
CPU_VALS=""
WIFI_VALS=""
OTHER_VALS=""

append_val() {
    local old="$1"
    local val="$2"
    if [ -n "$old" ]; then
        printf '%s %s' "$old" "$val"
    else
        printf '%s' "$val"
    fi
}

emit_json() {
    local name="$1"
    local path="$2"
    local raw="$3"
    local src="$4"

    case "$raw" in
        ''|*[!0-9-]*) return ;;
    esac

    local celsius ename epath esrc
    celsius="$(norm_c "$raw")"
    ename="$(printf '%s' "$name" | json_escape)"
    epath="$(printf '%s' "$path" | json_escape)"
    esrc="$(printf '%s' "$src" | json_escape)"

    [ "$first" = 0 ] && printf ',\n'
    first=0
    printf '    {"name":"%s","path":"%s","source":"%s","raw":%s,"celsius":%s}' \
        "$ename" "$epath" "$esrc" "$raw" "$celsius"
}

emit_summary() {
    local name="$1"
    local raw="$2"
    local src="$3"

    case "$raw" in
        ''|*[!0-9-]*) return ;;
    esac

    local celsius lower val
    celsius="$(norm_c "$raw")"
    val="${celsius}°C"
    lower="$(printf '%s %s' "$name" "$src" | tr 'A-Z' 'a-z')"

    case "$lower" in
        *wifi*|*wi-fi*|*wlan*|*radio*|*mt76*|*phy0*|*phy1*|*ieee80211*)
            WIFI_VALS="$(append_val "$WIFI_VALS" "$val")"
        ;;
        *cpu*)
            CPU_VALS="$(append_val "$CPU_VALS" "$val")"
        ;;
        *soc*)
            OTHER_VALS="$(append_val "$OTHER_VALS" "SoC: $val")"
        ;;
        *)
            OTHER_VALS="$(append_val "$OTHER_VALS" "$name: $val")"
        ;;
    esac
}

handle_temp() {
    local name="$1"
    local path="$2"
    local raw="$3"
    local src="$4"

    if [ "$MODE" = "json" ]; then
        emit_json "$name" "$path" "$raw" "$src"
    else
        emit_summary "$name" "$raw" "$src"
    fi
}

[ "$MODE" = "json" ] && printf '{"temps":[\n'

# Generic Linux thermal zones: CPU, SoC, WiFi, board sensors, etc. when exposed by kernel.
for z in /sys/class/thermal/thermal_zone*; do
    [ -r "$z/temp" ] || continue
    raw="$(cat "$z/temp" 2>/dev/null | tr -d '[:space:]')"
    type="$(cat "$z/type" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$type" ] || type="$(basename "$z")"
    handle_temp "$type" "$z/temp" "$raw" "thermal"
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
        handle_temp "${chip} ${label}" "$t" "$raw" "hwmon"
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
    handle_temp "${phy} WiFi" "$p" "$raw" "mt76-debugfs"
done

if [ "$MODE" = "json" ]; then
    printf '\n]}\n'
else
    OUT=""
    [ -n "$CPU_VALS" ] && OUT="CPU: $CPU_VALS"
    [ -n "$WIFI_VALS" ] && OUT="${OUT:+$OUT, }WiFi: $WIFI_VALS"
    [ -n "$OTHER_VALS" ] && OUT="${OUT:+$OUT, }$OTHER_VALS"
    [ -n "$OUT" ] || OUT="?"
    printf '%s\n' "$OUT"
fi
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

# Override the System status card directly. Do not add a second Temperatures card.
cat > files/www/luci-static/resources/view/status/include/10_system.js <<'EOF_SYSTEM_JS'
'use strict';
'require baseclass';
'require fs';
'require rpc';
'require uci';

var callGetUnixtime = rpc.declare({
	object: 'luci',
	method: 'getUnixtime',
	expect: { result: 0 }
});

var callLuciVersion = rpc.declare({
	object: 'luci',
	method: 'getVersion'
});

var callSystemBoard = rpc.declare({
	object: 'system',
	method: 'board'
});

var callSystemInfo = rpc.declare({
	object: 'system',
	method: 'info'
});

return baseclass.extend({
	title: _('System'),

	load: function() {
		return Promise.all([
			L.resolveDefault(callSystemBoard(), {}),
			L.resolveDefault(callSystemInfo(), {}),
			L.resolveDefault(callLuciVersion(), { revision: _('unknown version'), branch: 'LuCI' }),
			L.resolveDefault(callGetUnixtime(), 0),
			uci.load('system'),
			L.resolveDefault(fs.exec_direct('/sbin/tempinfo', [ 'summary' ], 'text'), '?')
		]);
	},

	render: function(data) {
		var boardinfo = data[0],
		    systeminfo = data[1],
		    luciversion = data[2],
		    unixtime = data[3],
		    temperatures = (data[5] || '?').trim();

		luciversion = luciversion.branch + ' ' + luciversion.revision;

		var datestr = null;
		if (unixtime) {
			var date = new Date(unixtime * 1000),
			    zn = uci.get('system', '@system[0]', 'zonename')?.replaceAll(' ', '_') || 'UTC',
			    ts = uci.get('system', '@system[0]', 'clock_timestyle') || 0,
			    hc = uci.get('system', '@system[0]', 'clock_hourcycle') || 0;

			datestr = new Intl.DateTimeFormat(undefined, {
				dateStyle: 'medium',
				timeStyle: (ts == 0) ? 'long' : 'full',
				hourCycle: (hc == 0) ? undefined : hc,
				timeZone: zn
			}).format(date);
		}

		var fields = [
			_('Hostname'),         boardinfo.hostname,
			_('Model'),            boardinfo.model,
			_('Architecture'),     boardinfo.system,
			_('Temperature'),      temperatures || '?',
			_('Target Platform'),  (L.isObject(boardinfo.release) ? boardinfo.release.target : ''),
			_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),
			_('Kernel Version'),   boardinfo.kernel,
			_('Local Time'),       datestr,
			_('Uptime'),           systeminfo.uptime ? '%t'.format(systeminfo.uptime) : null,
			_('Load Average'),     Array.isArray(systeminfo.load) ? '%.2f, %.2f, %.2f'.format(
								systeminfo.load[0] / 65535.0,
								systeminfo.load[1] / 65535.0,
								systeminfo.load[2] / 65535.0) : null
		];

		var table = E('table', { 'class': 'table' });

		for (var i = 0; i < fields.length; i += 2) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ fields[i] ]),
				E('td', { 'class': 'td left' }, [ (fields[i + 1] != null) ? fields[i + 1] : '?' ])
			]));
		}

		return table;
	}
});
EOF_SYSTEM_JS

cat > files/usr/sbin/extroot-status <<'EOF_EXTROOT_STATUS'
#!/bin/sh

echo "===== extroot status ====="
echo "rootfs: $(mount | awk '$3=="/" {print $1, $5}')"
echo "overlay: $(mount | awk '$3=="/overlay" {print $1, $5}')"
echo

echo "===== block info ====="
block info 2>/dev/null || true
echo

echo "===== fstab ====="
uci show fstab 2>/dev/null || true
echo

echo "===== candidate ext4 partitions ====="
for d in /dev/mmcblk*p* /dev/sd[a-z][0-9]*; do
    [ -b "$d" ] || continue
    info="$(block info "$d" 2>/dev/null || true)"
    echo "$d $info"
done

echo
echo "This script only reports status. It does not modify disks."
EOF_EXTROOT_STATUS

chmod +x files/usr/sbin/extroot-status

cat > files/usr/sbin/extroot-setup <<'EOF_EXTROOT_SETUP'
#!/bin/sh
set -e

usage() {
    cat <<'EOF'
Usage:
  extroot-setup /dev/mmcblk0pX
  extroot-setup /dev/sdXN

This is a MANUAL extroot helper.
It will format the target partition as ext4 and copy the current overlay.
It will not run automatically at boot.
EOF
}

DEV="$1"
[ -n "$DEV" ] || { usage; exit 1; }
[ -b "$DEV" ] || { echo "ERROR: block device not found: $DEV"; exit 1; }

case "$DEV" in
    /dev/mmcblk*p*|/dev/sd[a-z][0-9]*) ;;
    *) echo "ERROR: refuse suspicious target: $DEV"; exit 1 ;;
esac

echo "WARNING: this will erase $DEV"
echo "Type YES to continue:"
read ans
[ "$ans" = "YES" ] || { echo "cancelled"; exit 1; }

umount "$DEV" 2>/dev/null || true
mkfs.ext4 -F "$DEV"
mkdir -p /mnt/extroot
mount "$DEV" /mnt/extroot

echo "Copy current overlay to $DEV ..."
tar -C /overlay -cf - . | tar -C /mnt/extroot -xf -

UUID="$(block info "$DEV" | sed -n "s/.*UUID=\"\([^\"]*\)\".*/\1/p")"
[ -n "$UUID" ] || { echo "ERROR: cannot get UUID for $DEV"; exit 1; }

uci -q delete fstab.extroot || true
uci set fstab.extroot='mount'
uci set fstab.extroot.uuid="$UUID"
uci set fstab.extroot.target='/overlay'
uci set fstab.extroot.fstype='ext4'
uci set fstab.extroot.options='rw,sync,noatime'
uci set fstab.extroot.enabled='1'
uci set fstab.extroot.enabled_fsck='0'
uci commit fstab

sync
umount /mnt/extroot

echo "Done. Reboot manually to test extroot: reboot"
echo "If boot fails, recover by removing/changing the fstab extroot entry."
EOF_EXTROOT_SETUP

chmod +x files/usr/sbin/extroot-setup

echo "===== DIY part2 done ====="
