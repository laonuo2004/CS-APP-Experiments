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
  (cd misc && ./yis "${prog}.yo")
  echo "[OK] ${prog}"
done

