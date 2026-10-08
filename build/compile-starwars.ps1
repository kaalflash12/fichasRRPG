$ErrorActionPreference = 'Stop'
$sdkDir = Join-Path $env:RUNNER_TEMP 'FirecastSDK3'
$installer = Join-Path $env:RUNNER_TEMP 'RDK3.7.b.exe'
$sourceDir = Join-Path $env:RUNNER_TEMP 'StarWarsSaga734'

Invoke-WebRequest -Uri 'https://firecast.app/downloads/RDK3.7.b.exe' -OutFile $installer -TimeoutSec 120
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/NOICONS', ('/DIR="' + $sdkDir + '"'))
$setup = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru
if (-not $setup.WaitForExit(120000)) {
    $setup.Kill()
    throw 'O instalador oficial do RDK excedeu o tempo limite'
}
if ($setup.ExitCode -notin @(0, 3010)) { throw "Instalador RDK terminou com código $($setup.ExitCode)" }

$searchDirs = @($sdkDir, (Join-Path $env:LOCALAPPDATA 'FirecastSDK3'), (Join-Path $env:ProgramFiles 'FirecastSDK3'))
$rdk = $null
foreach ($dir in $searchDirs) {
    if (Test-Path -LiteralPath $dir) {
        $candidate = Get-ChildItem -LiteralPath $dir -Recurse -Filter 'rdk.exe' -File | Select-Object -First 1
        if ($candidate) { $rdk = $candidate.FullName; break }
    }
}
if (-not $rdk) { throw 'rdk.exe não encontrado após instalar o SDK oficial' }

Expand-Archive -LiteralPath './StarWarsSaga/source.zip' -DestinationPath $sourceDir -Force
Push-Location $sourceDir
try {
    & $rdk lint
    if ($LASTEXITCODE -ne 0) { throw "RDK lint falhou: $LASTEXITCODE" }
    & $rdk compile
    if ($LASTEXITCODE -ne 0) { throw "RDK compile falhou: $LASTEXITCODE" }
} finally {
    Pop-Location
}
$packages = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir 'output') -Filter '*.rpk' -File)
if ($packages.Count -ne 1) { throw 'A compilação não produziu exatamente um RPK' }
New-Item -ItemType Directory -Path './releases' -Force | Out-Null
$dest = Join-Path (Get-Location) 'releases/STARWARS_SAGA_7.3.4.rpk'
Copy-Item -LiteralPath $packages[0].FullName -Destination $dest -Force
python ./build/validate-release.py $sourceDir $dest
if ($LASTEXITCODE -ne 0) { throw 'Validação do pacote compilado falhou' }

$manifest = "SWSE-UPDATE-1`nmodule=MestreRPG.StarWarsSagaEdition`nversion=7.3.4`nrpk=https://raw.githubusercontent.com/kaalflash12/fichasRRPG/main/releases/STARWARS_SAGA_7.3.4.rpk`n"
[IO.File]::WriteAllText((Join-Path (Get-Location) 'update.txt'), $manifest, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath './build/README-publicado.md' -Destination './README.md' -Force
