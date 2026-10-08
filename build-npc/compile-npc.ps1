$ErrorActionPreference = 'Stop'
$sdkDir = Join-Path $env:RUNNER_TEMP 'FirecastSDK3NPC'
$installer = Join-Path $env:RUNNER_TEMP 'RDK3.7.b.exe'
$sourceDir = Join-Path $env:RUNNER_TEMP 'ControladorNPC'
Invoke-WebRequest -Uri 'https://firecast.app/downloads/RDK3.7.b.exe' -OutFile $installer -TimeoutSec 120
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/NOICONS', ('/DIR="' + $sdkDir + '"'))
$setup = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru
if (-not $setup.WaitForExit(120000)) { $setup.Kill(); throw 'Instalador RDK excedeu o tempo limite' }
if ($setup.ExitCode -notin @(0,3010)) { throw "Instalador RDK: $($setup.ExitCode)" }
$rdk = (Get-ChildItem -LiteralPath $sdkDir -Recurse -Filter 'rdk.exe' -File | Select-Object -First 1).FullName
if (-not $rdk) { throw 'rdk.exe não encontrado' }
Copy-Item -LiteralPath './ControladorNPC/source' -Destination $sourceDir -Recurse
# Reuse only the official SDK bridge bundled in the existing public sheet source.
$sdkSource = Join-Path $env:RUNNER_TEMP 'SharedSDK'
Expand-Archive -LiteralPath './StarWarsSaga/source.zip' -DestinationPath $sdkSource
Copy-Item -LiteralPath (Join-Path $sdkSource 'sdk') -Destination (Join-Path $sourceDir 'sdk') -Recurse
Push-Location $sourceDir
try {
    & $rdk lint
    if ($LASTEXITCODE -ne 0) { throw "RDK lint: $LASTEXITCODE" }
    & $rdk compile
    if ($LASTEXITCODE -ne 0) { throw "RDK compile: $LASTEXITCODE" }
} finally { Pop-Location }
$files = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir 'output') -Filter '*.rpk' -File)
if ($files.Count -ne 1) { throw 'Esperado exatamente um RPK do controlador' }
New-Item -ItemType Directory -Path './releases' -Force | Out-Null
$dest = Join-Path (Get-Location) 'releases/CONTROLADOR_NPC_STARWARS_1.0.0.rpk'
Copy-Item -LiteralPath $files[0].FullName -Destination $dest
python ./build-npc/validate-release.py $sourceDir $dest ./ControladorNPC/tests
if ($LASTEXITCODE -ne 0) { throw 'Validação do controlador falhou' }
Copy-Item -LiteralPath $dest -Destination './releases/CONTROLADOR_NPC_STARWARS.rpk' -Force
$manifest = "SWSE-UPDATE-1`nmodule=MestreRPG.SWSE.NPCController`nversion=1.0.0`nrpk=https://raw.githubusercontent.com/kaalflash12/fichasRRPG/main/releases/CONTROLADOR_NPC_STARWARS_1.0.0.rpk`n"
[IO.File]::WriteAllText((Join-Path (Get-Location) 'ControladorNPC/update.txt'), $manifest, [Text.UTF8Encoding]::new($false))
