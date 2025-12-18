#!/usr/bin/env bash
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
PIPE_DIR="$ROOT/pipe"

echo "== Part C: rebuilding PIPE (full) =="
make -C "$PIPE_DIR" clean >/dev/null
make -C "$PIPE_DIR" VERSION=full

echo
echo "== Part C: (re)generating drivers and fresh yo files =="
(cd "$PIPE_DIR" && make drivers && ../misc/yas ncopy.ys)

echo
echo "== Part C: sanity runs on sdriver/ldriver =="
(cd "$PIPE_DIR" && ./psim -t sdriver.yo)
(cd "$PIPE_DIR" && ./psim -t ldriver.yo)

echo
echo "== Part C: correctness against YIS =="
(cd "$PIPE_DIR" && ./correctness.pl)

echo
echo "== Part C: correctness against PSIM =="
(cd "$PIPE_DIR" && ./correctness.pl -p)

echo
echo "== Part C: size + performance =="
(cd "$PIPE_DIR" && ./check-len.pl < ncopy.yo)
(cd "$PIPE_DIR" && ./benchmark.pl)

echo
echo "[Done] Part C regression + benchmark completed."

