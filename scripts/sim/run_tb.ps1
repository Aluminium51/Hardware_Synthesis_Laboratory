$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$OutDir = Join-Path $Root "sim\run"
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$iverilog = $env:IVERILOG_BIN
$vvp = $env:VVP_BIN

if (-not $iverilog) {
    if (Get-Command iverilog -ErrorAction SilentlyContinue) {
        $iverilog = (Get-Command iverilog).Source
    } elseif (Test-Path "C:\iverilog\bin\iverilog.exe") {
        $iverilog = "C:\iverilog\bin\iverilog.exe"
    } elseif (Test-Path "C:\Program Files\iverilog\bin\iverilog.exe") {
        $iverilog = "C:\Program Files\iverilog\bin\iverilog.exe"
    } else {
        throw "iverilog not found. Install Icarus Verilog or set IVERILOG_BIN."
    }
}

if (-not $vvp) {
    if (Get-Command vvp -ErrorAction SilentlyContinue) {
        $vvp = (Get-Command vvp).Source
    } elseif (Test-Path "C:\iverilog\bin\vvp.exe") {
        $vvp = "C:\iverilog\bin\vvp.exe"
    } elseif (Test-Path "C:\Program Files\iverilog\bin\vvp.exe") {
        $vvp = "C:\Program Files\iverilog\bin\vvp.exe"
    } else {
        throw "vvp not found. Install Icarus Verilog or set VVP_BIN."
    }
}

function Invoke-TestBench {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string[]] $Sources
    )

    $out = Join-Path $OutDir ("{0}.vvp" -f $Name)
    Write-Host "[compile] $Name"
    & $iverilog -g2012 -o $out @Sources
    Write-Host "[run] $Name"
    & $vvp $out
}

Invoke-TestBench -Name "tb_linebuffer_ram" -Sources @(
    (Join-Path $Root "rtl\util\linebuffer_ram.v"),
    (Join-Path $Root "sim\tb\tb_linebuffer_ram.sv")
)

Invoke-TestBench -Name "tb_sliding_window_24" -Sources @(
    (Join-Path $Root "rtl\util\linebuffer_ram.v"),
    (Join-Path $Root "rtl\util\sliding_window_24.v"),
    (Join-Path $Root "sim\tb\tb_sliding_window_24.sv")
)

Invoke-TestBench -Name "tb_face_detect" -Sources @(
    (Join-Path $Root "rtl\top\face_detect.v"),
    (Join-Path $Root "sim\tb\tb_face_detect.sv")
)

Write-Host "All selected testbenches completed."
