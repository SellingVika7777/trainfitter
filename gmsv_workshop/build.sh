#!/usr/bin/env bash
# Trainfitter - build.sh
# Made by SellingVika

set -euo pipefail
cd "$(dirname "$0")"

rustup target add x86_64-unknown-linux-gnu i686-unknown-linux-gnu x86_64-pc-windows-msvc i686-pc-windows-msvc >/dev/null

if command -v cargo-zigbuild >/dev/null 2>&1; then
	cargo zigbuild --release --target x86_64-unknown-linux-gnu.2.17
	cargo zigbuild --release --target i686-unknown-linux-gnu.2.17
else
	cargo build --release --target x86_64-unknown-linux-gnu
	cargo build --release --target i686-unknown-linux-gnu
fi

mkdir -p bin
cp target/x86_64-unknown-linux-gnu/release/libgmsv_workshop.so bin/gmsv_workshop_linux64.dll
cp target/i686-unknown-linux-gnu/release/libgmsv_workshop.so bin/gmsv_workshop_linux.dll

if command -v cargo-xwin >/dev/null 2>&1; then
	cargo xwin build --release --target x86_64-pc-windows-msvc
	cargo xwin build --release --target i686-pc-windows-msvc
	cp target/x86_64-pc-windows-msvc/release/gmsv_workshop.dll bin/gmsv_workshop_win64.dll
	cp target/i686-pc-windows-msvc/release/gmsv_workshop.dll bin/gmsv_workshop_win32.dll
fi

ls -l bin
