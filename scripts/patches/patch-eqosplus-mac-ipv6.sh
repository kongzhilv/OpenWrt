#!/bin/sh
set -eu

echo "===== Patch EQOS Plus MAC filters: support IPv6/L2 traffic ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path

p = Path("package/luci-app-eqosplus/root/usr/bin/eqosplus")
if not p.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/root/usr/bin/eqosplus not found")

s = p.read_text(encoding="utf-8")
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
    p.write_text(s, encoding="utf-8")
    print("EQOS Plus MAC filters patched")
else:
    print("EQOS Plus MAC filters already patched")
PY_EQOSPLUS_PATCH
