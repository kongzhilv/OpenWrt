#!/bin/sh
set -eu

echo "===== Patch EQOS Plus MAC download filter: support IPv6/L2 traffic ====="

python3 - <<'PY_EQOSPLUS_PATCH'
from pathlib import Path

p = Path("package/luci-app-eqosplus/root/usr/bin/eqosplus")
if not p.exists():
    raise SystemExit("ERROR: package/luci-app-eqosplus/root/usr/bin/eqosplus not found")

s = p.read_text(encoding="utf-8")

if "parent 1:0 protocol all prio $id u32" in s:
    print("EQOS Plus patch already exists")
    raise SystemExit(0)

old = '''        $tc filter add dev ${dev} parent 1: protocol ip prio $id u32 \\
            match u16 0x0800 0xFFFF at -2 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id'''

new = '''        $tc filter add dev ${dev} parent 1:0 protocol all prio $id u32 \\
            match u32 0x${M1}${M2} 0xFFFFFFFF at -12 \\
            match u16 0x${M0} 0xFFFF at -14 \\
            flowid 1:$id'''

if old not in s:
    raise SystemExit("ERROR: EQOS Plus old MAC download filter block not found; upstream changed")

p.write_text(s.replace(old, new), encoding="utf-8")
print("EQOS Plus MAC download filter patched")
PY_EQOSPLUS_PATCH
