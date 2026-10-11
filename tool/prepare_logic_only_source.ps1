param([string]$Destination)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Destination) {
    $Destination = Join-Path $projectRoot ('build\logic-only-source\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
}
$outputRoot = [IO.Path]::GetFullPath($Destination)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\logic-only-source')) + [IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must be a new directory under build/logic-only-source.'
}
if (Test-Path -LiteralPath $outputRoot) { throw 'Destination already exists; nothing was overwritten.' }

$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'assets\asset_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $manifest.assets) {
    $source = Join-Path $projectRoot $entry.path
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw ('Asset hash mismatch: ' + $entry.path)
    }
}

New-Item -ItemType Directory -Path $outputRoot | Out-Null
# Only implementation inputs are copied. Caches, Git, signing secrets and PNGs are not.
foreach ($directory in @('lib', 'android', 'web', 'test', 'tool')) {
    $inputRoot = Join-Path $projectRoot $directory
    foreach ($file in Get-ChildItem -LiteralPath $inputRoot -File -Recurse) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1)
        if ($relative -match '(^|[\\/])(build|\.gradle|\.dart_tool)([\\/]|$)' -or
            $file.Name -in @('key.properties', 'local.properties') -or
            $file.Extension -in @('.jks', '.keystore')) { continue }
        $target = Join-Path $outputRoot $relative
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
}
foreach ($name in @('pubspec.lock', 'analysis_options.yaml', '.metadata')) {
    $source = Join-Path $projectRoot $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $outputRoot $name) }
}
New-Item -ItemType Directory -Path (Join-Path $outputRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\asset_manifest.json') -Destination (Join-Path $outputRoot 'assets\asset_manifest.json')
# Generated build-profile rewrite; the checked-in pubspec and media are untouched.
$pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw -Encoding UTF8
$logicPubspec = [regex]::Replace($pubspec, '(?m)^    - assets/legacy/\r?\n', '')
if ($logicPubspec -eq $pubspec) { throw 'Expected legacy asset declaration was not found.' }
[IO.File]::WriteAllText((Join-Path $outputRoot 'pubspec.yaml'), $logicPubspec, [Text.UTF8Encoding]::new($false))
Write-Output ('Logic-only source: ' + $outputRoot)
Write-Output ('Excluded media bytes: ' + (($manifest.assets | Measure-Object -Property bytes -Sum).Sum))
Write-Output 'No APK was built. Build this directory with the same applicationId/signing key and a higher versionCode.'
Write-Output 'For first installation or cleared app data, use the full APK, not a logic-only update.'
