#!/bin/sh
set -eu

echo "===== Patch EQOS Plus: tolerant IP/MAC UI choices and IPv6/L2 filters ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path
import re

script_path = Path("package/luci-app-eqosplus/root/usr/bin/eqosplus")
ui_path = Path("package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua")

if not script_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/root/usr/bin/eqosplus not found")
if not ui_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua not found")

s = script_path.read_text(encoding="utf-8")
orig_s = s

# MAC mode must classify L2 frames, not only IPv4 frames. Use small, tolerant
# substitutions instead of exact multi-line blocks because upstream changes
# whitespace and line wrapping occasionally.
s = s.replace(
    "$tc filter add dev ${dev} parent 1: protocol ip prio $id u32",
    "$tc filter add dev ${dev} parent 1:0 protocol all prio $id u32",
)
s = s.replace(
    "$tc filter add dev ${dev}_ifb parent 1: protocol ip prio $((id + 100)) u32",
    "$tc filter add dev ${dev}_ifb parent 1:0 protocol all prio $((id + 100)) u32",
)

# Drop the old IPv4 EtherType guard from MAC/L2 filters. Keep IP-mode filters
# untouched; they use match ip src/dst and should stay protocol ip.
s = re.sub(r"\n[ \t]*match u16 0x0800 0xFFFF at -2[ \t]*\\", "", s)

# Normalize MAC input once it is known to be a MAC address. Manual input may use
# AA-BB-CC-DD-EE-FF while add_mac() splits on ':' later.
if "mac=\"$(echo \"$mac\" | tr '-' ':' | tr 'a-f' 'A-F')\"" not in s:
    s = re.sub(
        r"(add_mac\(\) \{\n[ \t]*local list_id=\$1\n[ \t]*id=\$\(\(list_id \* 10 \+ 1000\)\)\n)",
        r"\1    mac=\"$(echo \"$mac\" | tr '-' ':' | tr 'a-f' 'A-F')\"\n",
        s,
        count=1,
    )

# Normalize MAC before deleting nft rules too.
if re.search(r"if is_macaddr \"\$mac\"; then\n[ \t]*mac=\"\$\(echo \"\$mac\" \| tr '-' ':' \| tr 'a-f' 'A-F'\)\"", s) is None:
    s = s.replace(
        '        if is_macaddr "$mac"; then\n',
        '        if is_macaddr "$mac"; then\n            mac="$(echo "$mac" | tr \'-\' \':\' | tr \'a-f\' \'A-F\')"\n',
        1,
    )

required_script_snippets = [
    "parent 1:0 protocol all",
    "mac=\"$(echo \"$mac\" | tr '-' ':' | tr 'a-f' 'A-F')\"",
    "match u32 0x${M1}${M2} 0xFFFFFFFF at -12",
    "match u32 0x${M0}${M1} 0xFFFFFFFF at -8",
]
for snippet in required_script_snippets:
    if snippet not in s:
        raise SystemExit(f"ERROR: EQOS Plus script validation failed, missing: {snippet}")

if "match u16 0x0800 0xFFFF at -2" in s:
    raise SystemExit("ERROR: EQOS Plus script validation failed, old IPv4-only MAC guard still present")

if s != orig_s:
    script_path.write_text(s, encoding="utf-8")
    print("EQOS Plus MAC filters and normalization patched")
else:
    print("EQOS Plus MAC filters and normalization already patched")

u = ui_path.read_text(encoding="utf-8")
orig_u = u

# Fix dhcp.leases parsing: file format is expires mac ip hostname clientid.
u = u.replace(
    '                local mac, ip_lease, _, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")\n                if ip_lease == ip and hostname ~= "*" then',
    '                local _, lease_mac, ip_lease, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")\n                if ip_lease == ip and hostname ~= "*" then',
)

# Fix ip neigh parsing: capture the MAC after lladdr, not neighbor state.
u = u.replace(
    '            local ip_addr, mac = line:match("^(%S+)%s+.+%s+(%S+)%s+")',
    '            local ip_addr, mac = line:match("^(%S+)%s+dev%s+%S+%s+lladdr%s+([0-9A-Fa-f:]+)")',
)

# Keep editable Value input/autocomplete. Do not use ListValue.
u = re.sub(
    r'ip = t:option\((?:Value|ListValue), "mac"[^\n]*\)\n[ \t]*ip\.size = \d+',
    'ip = t:option(Value, "mac", translate("Limit target"), translate("IP only matches IPv4; MAC matches IPv4/IPv6."))\nip.size = 40',
    u,
    count=1,
)

# Replace the generated device choices with short, obvious labels. The saved
# values remain different: dev.ip for IP mode, dev.mac for MAC/L2 mode.
new_ui_value = '''for _, dev in ipairs(devices) do
    local name = dev.hostname
    if not name or name == "" or name == "unknown" then
        name = "Unknown device"
    end
    ip:value(dev.ip, string.format("IP  %s  %s", dev.ip, name))
    ip:value(dev.mac, string.format("MAC %s  %s", dev.mac, name))
end'''

patterns = [
    r'for _, dev in ipairs\(devices\) do\n[ \t]*ip:value\(dev\.ip, dev\.display\)\nend',
    r'for _, dev in ipairs\(devices\) do\n[ \t]*-- Save the MAC address.*?\n[ \t]*ip:value\(dev\.mac, dev\.display\)\nend',
    r'for _, dev in ipairs\(devices\) do\n[ \t]*-- Offer both choices.*?\n[ \t]*ip:value\(dev\.ip, "\[IP\] " .. dev\.display\)\n[ \t]*ip:value\(dev\.mac, "\[MAC\] " .. dev\.display\)\nend',
    r'for _, dev in ipairs\(devices\) do\n[ \t]*-- Keep one device visually grouped.*?\n[ \t]*local name = dev\.hostname\n[\s\S]*?ip:value\(dev\.mac, string\.format\("%s  \|  按MAC限速 \|  MAC %s  \|  IP %s", name, dev\.mac, dev\.ip\)\)\nend',
    r'for _, dev in ipairs\(devices\) do\n[ \t]*local name = dev\.hostname\n[\s\S]*?ip:value\(dev\.mac, string\.format\("%s  ->  MAC %s", base, dev\.mac\)\)\nend',
    r'for _, dev in ipairs\(devices\) do\n[ \t]*local name = dev\.hostname\n[\s\S]*?ip:value\(dev\.mac, string\.format\("MAC %s  %s", dev\.mac, name\)\)\nend',
]
for pat in patterns:
    u2, n = re.subn(pat, new_ui_value, u, count=1, flags=re.S)
    if n:
        u = u2
        break
else:
    raise SystemExit("ERROR: EQOS Plus UI device value block not found; upstream changed")

if "ip:value(dev.ip" not in u or "ip:value(dev.mac" not in u:
    raise SystemExit("ERROR: EQOS Plus UI validation failed, IP/MAC dual choices missing")
if 't:option(ListValue, "mac"' in u:
    raise SystemExit("ERROR: EQOS Plus UI validation failed, ListValue must not be used")
if 'IP  %s  %s' not in u or 'MAC %s  %s' not in u:
    raise SystemExit("ERROR: EQOS Plus UI validation failed, short IP/MAC labels missing")

if u != orig_u:
    ui_path.write_text(u, encoding="utf-8")
    print("EQOS Plus UI patched")
else:
    print("EQOS Plus UI already patched")
PY_EQOSPLUS_PATCH
