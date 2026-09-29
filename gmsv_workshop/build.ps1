# Trainfitter - build.ps1
# Made by SellingVika

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
$zigDir = (& python -c "import ziglang, os; print(os.path.dirname(ziglang.__file__))") 2>$null
if ($zigDir) { $env:PATH = "$zigDir;$env:PATH" }

rustup target add x86_64-pc-windows-msvc i686-pc-windows-msvc x86_64-unknown-linux-gnu i686-unknown-linux-gnu | Out-Null

cargo build --release --target x86_64-pc-windows-msvc
cargo build --release --target i686-pc-windows-msvc
cargo zigbuild --release --target x86_64-unknown-linux-gnu.2.17
cargo zigbuild --release --target i686-unknown-linux-gnu.2.17

New-Item -ItemType Directory -Force bin | Out-Null
Copy-Item target\x86_64-pc-windows-msvc\release\gmsv_workshop.dll bin\gmsv_workshop_win64.dll -Force
Copy-Item target\i686-pc-windows-msvc\release\gmsv_workshop.dll bin\gmsv_workshop_win32.dll -Force
Copy-Item target\x86_64-unknown-linux-gnu\release\libgmsv_workshop.so bin\gmsv_workshop_linux64.dll -Force
Copy-Item target\i686-unknown-linux-gnu\release\libgmsv_workshop.so bin\gmsv_workshop_linux.dll -Force

Get-ChildItem bin | Format-Table Name, Length
