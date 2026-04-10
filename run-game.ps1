$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotExe = "C:\Users\weave\Dev\Godot\Godot_v4.6.2-stable_win64.exe"

if (-not (Test-Path -LiteralPath $godotExe)) {
    throw "Godot executable not found at: $godotExe"
}

Start-Process -FilePath $godotExe -WorkingDirectory $projectRoot -ArgumentList @("--path", $projectRoot)
