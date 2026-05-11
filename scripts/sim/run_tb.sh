#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/sim/run"

mkdir -p "$OUT_DIR"

IVERILOG_BIN="${IVERILOG_BIN:-}"
VVP_BIN="${VVP_BIN:-}"

if [[ -z "$IVERILOG_BIN" ]]; then
	if command -v iverilog >/dev/null 2>&1; then
		IVERILOG_BIN="$(command -v iverilog)"
	elif [[ -x "/c/iverilog/bin/iverilog.exe" ]]; then
		IVERILOG_BIN="/c/iverilog/bin/iverilog.exe"
	elif [[ -x "/c/Program Files/iverilog/bin/iverilog.exe" ]]; then
		IVERILOG_BIN="/c/Program Files/iverilog/bin/iverilog.exe"
	else
		echo "ERROR: iverilog not found. Set IVERILOG_BIN or install Icarus Verilog."
		exit 1
	fi
fi

if [[ -z "$VVP_BIN" ]]; then
	if command -v vvp >/dev/null 2>&1; then
		VVP_BIN="$(command -v vvp)"
	elif [[ -x "/c/iverilog/bin/vvp.exe" ]]; then
		VVP_BIN="/c/iverilog/bin/vvp.exe"
	elif [[ -x "/c/Program Files/iverilog/bin/vvp.exe" ]]; then
		VVP_BIN="/c/Program Files/iverilog/bin/vvp.exe"
	else
		echo "ERROR: vvp not found. Set VVP_BIN or install Icarus Verilog."
		exit 1
	fi
fi

run_tb() {
	local name="$1"
	shift
	local out="$OUT_DIR/${name}.vvp"
	echo "[compile] $name"
	"$IVERILOG_BIN" -g2012 -o "$out" "$@"
	echo "[run] $name"
	"$VVP_BIN" "$out"
}

run_tb tb_linebuffer_ram \
	"$ROOT_DIR/rtl/util/linebuffer_ram.v" \
	"$ROOT_DIR/sim/tb/tb_linebuffer_ram.sv"

run_tb tb_sliding_window_24 \
	"$ROOT_DIR/rtl/util/linebuffer_ram.v" \
	"$ROOT_DIR/rtl/util/sliding_window_24.v" \
	"$ROOT_DIR/sim/tb/tb_sliding_window_24.sv"

run_tb tb_face_detect \
	"$ROOT_DIR/rtl/top/face_detect.v" \
	"$ROOT_DIR/sim/tb/tb_face_detect.sv"

echo "All selected testbenches completed."
