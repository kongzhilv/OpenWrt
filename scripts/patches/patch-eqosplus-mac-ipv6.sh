#!/bin/sh
set -eu

echo "===== Patch EQOS Plus: UI choices, backend device indexes and low-latency queues ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path
import re

ui_path = Path("package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua")
backend_path = Path("package/luci-app-eqosplus/root/usr/bin/eqosplus")

if not ui_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/luasrc/model/cbi/eqosplus.lua not found")
if not backend_path.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/root/usr/bin/eqosplus not found")

u = ui_path.read_text(encoding="utf-8")
orig_u = u

# LuCI target chooser fixes:
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

# Replace the generated device choices. Saved values remain the same real option:
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

b = backend_path.read_text(encoding="utf-8")
orig_b = b

# Backend fixes validated on the target router:
# - keep full multi-digit @device indexes such as [10], [11], ... instead of
#   splitting them into 1 and 0; this allows more than 10 configured devices.
# - replace per-device SFQ leaves with fq_codel for lower queueing delay.
# - increase the IFB tx queue length before attaching HTB leaves.
# - add IPv6 MAC/fw filters so MAC based rules are not IPv4-only.
b = b.replace("grep -oE '\\[.*?\\]' | grep -o '[0-9]'", "grep -oE '\\[.*?\\]' | grep -oE '[0-9]+'")

b = b.replace(
    '    $ip link set dev ${dev}_ifb up\n',
    '    $ip link set dev ${dev}_ifb up\n    $ip link set dev ${dev}_ifb txqueuelen 1000 2>/dev/null || true\n',
)

fq_codel_line = 'fq_codel limit 256 flows 128 quantum 1514 target 5ms interval 100ms ecn'
b = b.replace(
    '        $tc qdisc add dev ${dev}_ifb parent 1:$id handle ${id}: sfq perturb 10',
    f'        $tc qdisc add dev ${{dev}}_ifb parent 1:$id handle ${{id}}: {fq_codel_line}',
)
b = b.replace(
    '        $tc qdisc add dev ${dev} parent 1:$id handle ${id}: sfq perturb 10',
    f'        $tc qdisc add dev ${{dev}} parent 1:$id handle ${{id}}: {fq_codel_line}',
)

# Add IPv6 classification next to the existing IPv4 filters in MAC mode. The
# IPv6 rule mirrors the same MAC byte offsets but matches EtherType 0x86dd.
b = b.replace(
    '''        $tc filter add dev ${dev}_ifb parent 1: protocol ip prio $id handle $id fw flowid 1:$id

        $tc filter add dev ${dev}_ifb parent 1: protocol ip prio $((id + 100)) u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u16 0x${M2} 0xFFFF at -4 \\
            match u32 0x${M0}${M1} 0xFFFFFFFF at -8 \\
            flowid 1:$id''',
    '''        $tc filter add dev ${dev}_ifb parent 1: protocol ip prio $id handle $id fw flowid 1:$id
        $tc filter add dev ${dev}_ifb parent 1: protocol ipv6 prio $((id + 1000)) handle $id fw flowid 1:$id

        $tc filter add dev ${dev}_ifb parent 1: protocol ip prio $((id + 100)) u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u16 0x${M2} 0xFFFF at -4 \\
            match u32 0x${M0}${M1} 0xFFFFFFFF at -8 \\
            flowid 1:$id
        $tc filter add dev ${dev}_ifb parent 1: protocol ipv6 prio $((id + 1100)) u32 \\
            match u16 0x86dd 0xFFFF at -2 \\
            match u16 0x${M2} 0xFFFF at -4 \\
            match u32 0x${M0}${M1} 0xFFFFFFFF at -8 \\
            flowid 1:$id''',
)

b = b.replace(
    '''        $tc filter add dev ${dev} parent 1: protocol ip prio $id u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id''',
    '''        $tc filter add dev ${dev} parent 1: protocol ip prio $id u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id
        $tc filter add dev ${dev} parent 1: protocol ipv6 prio $((id + 1000)) u32 \\
            match u16 0x86dd 0xFFFF at -2 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id''',
)

required_backend_snippets = [
    "grep -oE '[0-9]+'",
    "txqueuelen 1000",
    fq_codel_line,
    "protocol ipv6",
]
for snippet in required_backend_snippets:
    if snippet not in b:
        raise SystemExit(f"ERROR: EQOS Plus backend validation failed, missing: {snippet}")

for forbidden in [
    "grep -o '[0-9]'",
    "sfq perturb 10",
]:
    if forbidden in b:
        raise SystemExit(f"ERROR: EQOS Plus backend validation failed, forbidden leftover: {forbidden}")

if b != orig_b:
    backend_path.write_text(b, encoding="utf-8")
    print("EQOS Plus backend multi-device and fq_codel patch applied")
else:
    print("EQOS Plus backend already patched")
PY_EQOSPLUS_PATCH
