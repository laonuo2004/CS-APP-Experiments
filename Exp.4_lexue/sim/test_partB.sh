#!/usr/bin/env bash
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
SEQ_DIR="$ROOT/seq"

echo "== Part B: rebuilding SEQ (full) =="
make -C "$SEQ_DIR" clean >/dev/null
make -C "$SEQ_DIR" VERSION=full

echo
echo "== Part B: quick ISA check on asumi.yo =="
(cd "$SEQ_DIR" && ./ssim -t ../y86-code/asumi.yo)

echo
echo "== Part B: y86-code regression =="
(cd "$ROOT/y86-code" && make testssim)

echo
echo "== Part B: ptest (includes iaddq suite) =="
(cd "$ROOT/ptest" && make SIM=../seq/ssim TFLAGS=-i)

echo
echo "[Done] Part B test suite finished."

