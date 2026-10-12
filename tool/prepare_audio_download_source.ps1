param([string]$Destination)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Destination) {
    $Destination = Join-Path $projectRoot ('build\audio-download-source\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
}
$outputRoot = [IO.Path]::GetFullPath($Destination)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\audio-download-source')) + [IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must be a new directory under build/audio-download-source.'
}
if (Test-Path -LiteralPath $outputRoot) { throw 'Destination exists; nothing overwritten.' }
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'assets\audio_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $manifest.assets) {
    $source = Join-Path $projectRoot $entry.path
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw ('Audio hash mismatch: ' + $entry.path)
    }
}
New-Item -ItemType Directory -Path $outputRoot | Out-Null
foreach ($directory in @('lib', 'android', 'web', 'test', 'tool', 'assets')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -File -Recurse) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1)
        if ($relative -match '(^|[\/])(build|\.gradle|\.dart_tool)([\/]|$)' -or
            $relative -match '^assets[\/]audio[\/]' -or
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
$pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw -Encoding UTF8
$audioDownloadPubspec = [regex]::Replace($pubspec, '(?m)^    - assets/audio/\r?\n', '')
if ($audioDownloadPubspec -eq $pubspec) { throw 'Audio asset declaration missing.' }
# Mechanical generated build profile only; checked-in source is untouched.
[IO.File]::WriteAllText((Join-Path $outputRoot 'pubspec.yaml'), $audioDownloadPubspec, [Text.UTF8Encoding]::new($false))
Write-Output ('Audio-download source: ' + $outputRoot)
Write-Output 'PNG images remain included for a new installation; music/effects are downloaded once.'
Write-Output 'Publish the verified audio ZIP before distributing this build. No APK was built.'
