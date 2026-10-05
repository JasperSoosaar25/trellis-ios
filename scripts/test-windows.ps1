$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$sdkLocation = [Environment]::GetEnvironmentVariable('SDKROOT', 'User')
if (-not $sdkLocation) { $sdkLocation = [Environment]::GetEnvironmentVariable('SDKROOT', 'Machine') }
if ($sdkLocation) { $env:SDKROOT = $sdkLocation }
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswherePath)) { throw 'Install Visual Studio C++ Build Tools and Windows SDK first.' }
$vsLocation = & $vswherePath -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsLocation) { throw 'Visual Studio C++ tools are missing.' }
$developerShell = Join-Path $vsLocation 'Common7\Tools\Launch-VsDevShell.ps1'
& $developerShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
swift --version
swift test --package-path (Join-Path $projectRoot 'Packages\GitHubKit')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
