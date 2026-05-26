#!/bin/sh
set -eu

echo "===== Patch EQOS Plus: IP/MAC UI choices and IPv6/L2 filters ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path

script_path = Path("package/luci-app-eqosplus/root/usr/bin/eqosplus")
ui_path = Path("package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua")

if not script_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/root/usr/bin/eqosplus not found")
if not ui_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua not found")

s = script_path.read_text(encoding="utf-8")
changed = False

old_down = '''        $tc filter add dev ${dev} parent 1: protocol ip prio $id u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id'''

new_down = '''        $tc filter add dev ${dev} parent 1:0 protocol all prio $id u32 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id'''

old_up = '''        $tc filter add dev ${dev}_ifb parent 1: protocol ip prio $((id + 100)) u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u16 0x${M2} 0xFFFF at -4 \\
            match u32 0x${M0}${M1} 0xFFFFFFFF at -8 \\
            flowid 1:$id'''

new_up = '''        $tc filter add dev ${dev}_ifb parent 1:0 protocol all prio $((id + 100)) u32 \\
            match u16 0x${M2} 0xFFFF at -4 \\
            match u32 0x${M0}${M1} 0xFFFFFFFF at -8 \\
            flowid 1:$id'''

if old_down in s:
    s = s.replace(old_down, new_down)
    changed = True
    print("patched download MAC filter")
elif new_down in s:
    print("download MAC filter already patched")
else:
    raise SystemExit("ERROR: EQOS Plus old MAC download filter block not found; upstream changed")

if old_up in s:
    s = s.replace(old_up, new_up)
    changed = True
    print("patched upload MAC filter")
elif new_up in s:
    print("upload MAC filter already patched")
else:
    raise SystemExit("ERROR: EQOS Plus old MAC upload filter block not found; upstream changed")

if changed:
    script_path.write_text(s, encoding="utf-8")
    print("EQOS Plus MAC filters patched")
else:
    print("EQOS Plus MAC filters already patched")

u = ui_path.read_text(encoding="utf-8")
ui_changed = False

old_ui_field = '''ip = t:option(Value, "mac", translate("IP/MAC"))
ip.size = 8
'''
new_ui_field = '''ip = t:option(Value, "mac", translate("Device IP/MAC"), translate("Select either IP or MAC. MAC is recommended for IPv6 and DHCP address changes; IP/CIDR is still supported."))
ip.size = 22
'''

if old_ui_field in u:
    u = u.replace(old_ui_field, new_ui_field)
    ui_changed = True
    print("patched UI field label/description")
elif new_ui_field in u:
    print("UI field label/description already patched")
else:
    raise SystemExit("ERROR: EQOS Plus UI IP/MAC field block not found; upstream changed")

old_ui_value = '''for _, dev in ipairs(devices) do
    ip:value(dev.ip, dev.display)
end
'''
new_ui_value = '''for _, dev in ipairs(devices) do
    -- Offer both choices explicitly: IP is useful for IP/CIDR rules, MAC is better for IPv6 and DHCP changes.
    ip:value(dev.ip, "[IP] " .. dev.display)
    ip:value(dev.mac, "[MAC] " .. dev.display)
end
'''
old_mac_only_value = '''for _, dev in ipairs(devices) do
    -- Save the MAC address instead of IPv4, so IPv6 and DHCP address changes remain limited.
    ip:value(dev.mac, dev.display)
end
'''

if old_ui_value in u:
    u = u.replace(old_ui_value, new_ui_value)
    ui_changed = True
    print("patched UI device choices to offer IP and MAC")
elif old_mac_only_value in u:
    u = u.replace(old_mac_only_value, new_ui_value)
    ui_changed = True
    print("patched UI MAC-only choices to offer IP and MAC")
elif new_ui_value in u:
    print("UI device choices already offer IP and MAC")
else:
    raise SystemExit("ERROR: EQOS Plus UI device value block not found; upstream changed")

if ui_changed:
    ui_path.write_text(u, encoding="utf-8")
    print("EQOS Plus UI patched to select/save either IP or MAC")
else:
    print("EQOS Plus UI already patched")
PY_EQOSPLUS_PATCH
