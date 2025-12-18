#!/usr/bin/env bash
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
cd "$ROOT"

echo "== Part A smoke tests =="
progs=(sum rsum copy)
for prog in "${progs[@]}"; do
  echo
  echo "[Assembling] ${prog}.ys"
  (cd misc && ./yas "${prog}.ys")
  echo "[Simulating] ${prog}.yo with yis"

  OUTPUT=$(cd misc && ./yis "${prog}.yo" | tee /dev/tty)
  
  if echo "$OUTPUT" | grep -q "rax:.*0x0000000000000cba"; then
      echo "[PASS] ${prog} returned correct result (0xcba)."
  else
      echo "[FAIL] ${prog} did NOT return 0xcba!"
      exit 1
  fi
done

