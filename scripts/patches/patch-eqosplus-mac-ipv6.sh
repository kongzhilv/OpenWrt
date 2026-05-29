#!/bin/sh
set -eu

echo "===== Patch EQOS Plus: clean IP/MAC UI choices only ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path
import re

ui_path = Path("package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua")

if not ui_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua not found")

u = ui_path.read_text(encoding="utf-8")
orig_u = u

# Keep upstream backend logic unchanged. Only improve the LuCI target chooser:
# - keep the original editable IP/MAC Value field
# - offer both IP and MAC candidates in the same chooser
# - parse `ip neigh` by lladdr so STALE/REACHABLE are never shown as MACs
# `ip neigh` syntax is: ADDR dev DEV lladdr LLADDRESS nud STATE.

# Fix dhcp.leases parsing: file format is expires mac ip hostname clientid.
u = u.replace(
    '                local mac, ip_lease, _, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")\n                if ip_lease == ip and hostname ~= "*" then',
    '                local _, lease_mac, ip_lease, hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")\n                if ip_lease == ip and hostname ~= "*" then',
)

# Fix ip neigh parsing: capture the MAC after lladdr, not the neighbor state.
u = re.sub(
    r'local ip_addr, mac = line:match\("\^\(%S\+\)%s\+\.\+%s\+\(%S\+\)%s\+"\)',
    'local ip_addr, mac = line:match("^(%d+%.%d+%.%d+%.%d+).-[Ll][Ll][Aa][Dd][Dd][Rr]%s+([0-9A-Fa-f:]+)")',
    u,
    count=1,
)

# Replace the generated device choices. Save values remain the same real option:
# dev.ip triggers IP mode, dev.mac triggers MAC mode in the original backend.
new_choices = '''local devices = get_devices()
for _, dev in ipairs(devices) do
    local name = dev.hostname or "unknown"
    if name == "" then name = "unknown" end
    if dev.ip and dev.ip ~= "" then
        ip:value(dev.ip, string.format("[IP]  %s | %s", dev.ip, name))
    end
    if dev.mac and dev.mac:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then
        ip:value(dev.mac, string.format("[MAC] %s | %s", dev.mac, name))
    end
end'''

u, choice_count = re.subn(
    r'local devices = get_devices\(\)\nfor _, dev in ipairs\(devices\) do\n[\s\S]*?\nend\ndl = t:option',
    new_choices + '\ndl = t:option',
    u,
    count=1,
)
if choice_count != 1:
    raise SystemExit("ERROR: EQOS Plus UI device choice block not found; upstream changed")

required_ui_snippets = [
    'ip = t:option(Value, "mac", translate("IP/MAC"))',
    'local ip_addr, mac = line:match("^(%d+%.%d+%.%d+%.%d+).-[Ll][Ll][Aa][Dd][Dd][Rr]%s+([0-9A-Fa-f:]+)")',
    'ip:value(dev.ip, string.format("[IP]  %s | %s", dev.ip, name))',
    'ip:value(dev.mac, string.format("[MAC] %s | %s", dev.mac, name))',
]
for snippet in required_ui_snippets:
    if snippet not in u:
        raise SystemExit(f"ERROR: EQOS Plus UI validation failed, missing: {snippet}")

for forbidden in [
    't:option(ListValue, "_target_pick"',
    'pick.write = function',
    '手动输入目标',
    '选择设备',
    'devices fallback',
    'ip:value(dev.mac, dev.display)',
]:
    if forbidden in u:
        raise SystemExit(f"ERROR: EQOS Plus UI validation failed, forbidden leftover: {forbidden}")

if u != orig_u:
    ui_path.write_text(u, encoding="utf-8")
    print("EQOS Plus UI IP/MAC choices patched")
else:
    print("EQOS Plus UI IP/MAC choices already patched")
PY_EQOSPLUS_PATCH
