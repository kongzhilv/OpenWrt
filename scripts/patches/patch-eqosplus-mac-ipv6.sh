#!/bin/sh
set -eu

echo "===== Patch EQOS Plus: clean IP/MAC UI choices, neighbor parsing and IPv6/L2 filters ====="

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

# Fix dhcp.leases parsing: file format is expires mac ip hostname clientid.
old_lease_parse = '''                local mac, ip_lease, _, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
                if ip_lease == ip and hostname ~= "*" then'''
new_lease_parse = '''                local _, lease_mac, ip_lease, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
                if ip_lease == ip and hostname ~= "*" then'''
if old_lease_parse in u:
    u = u.replace(old_lease_parse, new_lease_parse)
    ui_changed = True
    print("patched DHCP lease parsing")
elif new_lease_parse in u:
    print("DHCP lease parsing already patched")
else:
    print("WARN: DHCP lease parsing block not found")

# Fix ip neigh parsing: capture the MAC after lladdr, not the neighbor state such as REACHABLE/STALE/DELAY.
old_neigh_parse = '''            local ip_addr, mac = line:match("^(%S+)%s+.+%s+(%S+)%s+")'''
new_neigh_parse = '''            local ip_addr, mac = line:match("^(%S+)%s+dev%s+%S+%s+lladdr%s+([0-9A-Fa-f:]+)")'''
if old_neigh_parse in u:
    u = u.replace(old_neigh_parse, new_neigh_parse)
    ui_changed = True
    print("patched IPv4 neighbor MAC parsing")
elif new_neigh_parse in u:
    print("IPv4 neighbor MAC parsing already patched")
else:
    print("WARN: IPv4 neighbor parsing block not found")

old_ui_field = '''ip = t:option(Value, "mac", translate("IP/MAC"))
ip.size = 8
'''
old_ui_field2 = '''ip = t:option(Value, "mac", translate("Device IP/MAC"), translate("Select either IP or MAC. MAC is recommended for IPv6 and DHCP address changes; IP/CIDR is still supported."))
ip.size = 22
'''
old_ui_field3 = '''ip = t:option(Value, "mac", translate("Device IP/MAC"), translate("Each device has two choices: limit by IP or limit by MAC. MAC is recommended for IPv6 and DHCP address changes."))
ip.size = 32
'''
new_ui_field = '''ip = t:option(Value, "mac", translate("Limit target"), translate("Choose by IP or by MAC."))
ip.size = 40
'''

if old_ui_field in u:
    u = u.replace(old_ui_field, new_ui_field)
    ui_changed = True
    print("patched UI field label/description")
elif old_ui_field2 in u:
    u = u.replace(old_ui_field2, new_ui_field)
    ui_changed = True
    print("updated UI field label/description")
elif old_ui_field3 in u:
    u = u.replace(old_ui_field3, new_ui_field)
    ui_changed = True
    print("shortened UI field label/description")
elif new_ui_field in u:
    print("UI field label/description already patched")
else:
    raise SystemExit("ERROR: EQOS Plus UI IP/MAC field block not found; upstream changed")

old_ui_value = '''for _, dev in ipairs(devices) do
    ip:value(dev.ip, dev.display)
end
'''
old_mac_only_value = '''for _, dev in ipairs(devices) do
    -- Save the MAC address instead of IPv4, so IPv6 and DHCP address changes remain limited.
    ip:value(dev.mac, dev.display)
end
'''
old_ipmac_value = '''for _, dev in ipairs(devices) do
    -- Offer both choices explicitly: IP is useful for IP/CIDR rules, MAC is better for IPv6 and DHCP changes.
    ip:value(dev.ip, "[IP] " .. dev.display)
    ip:value(dev.mac, "[MAC] " .. dev.display)
end
'''
old_clean_value = '''for _, dev in ipairs(devices) do
    -- Keep one device visually grouped by putting hostname first, then the selected limit mode.
    local name = dev.hostname
    if not name or name == "" or name == "unknown" then
        name = "Unknown device"
    end
    ip:value(dev.ip, string.format("%s  |  按IP限速  |  IP %s  |  MAC %s", name, dev.ip, dev.mac))
    ip:value(dev.mac, string.format("%s  |  按MAC限速 |  MAC %s  |  IP %s", name, dev.mac, dev.ip))
end
'''
new_ui_value = '''for _, dev in ipairs(devices) do
    local name = dev.hostname
    if not name or name == "" or name == "unknown" then
        name = "Unknown device"
    end
    local base = string.format("%s  [%s]", name, dev.ip)
    ip:value(dev.ip, string.format("%s  ->  IP", base))
    ip:value(dev.mac, string.format("%s  ->  MAC %s", base, dev.mac))
end
'''

if old_ui_value in u:
    u = u.replace(old_ui_value, new_ui_value)
    ui_changed = True
    print("patched UI device choices to compact IP/MAC labels")
elif old_mac_only_value in u:
    u = u.replace(old_mac_only_value, new_ui_value)
    ui_changed = True
    print("patched UI MAC-only choices to compact IP/MAC labels")
elif old_ipmac_value in u:
    u = u.replace(old_ipmac_value, new_ui_value)
    ui_changed = True
    print("updated UI IP/MAC choices to compact labels")
elif old_clean_value in u:
    u = u.replace(old_clean_value, new_ui_value)
    ui_changed = True
    print("updated UI clean labels to compact labels")
elif new_ui_value in u:
    print("UI device choices already use compact IP/MAC labels")
else:
    raise SystemExit("ERROR: EQOS Plus UI device value block not found; upstream changed")

if ui_changed:
    ui_path.write_text(u, encoding="utf-8")
    print("EQOS Plus UI patched")
else:
    print("EQOS Plus UI already patched")
PY_EQOSPLUS_PATCH
