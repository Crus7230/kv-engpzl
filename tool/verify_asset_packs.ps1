$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($pack in @(
    @('assets\asset_manifest.json', 'build\asset-pack\r1-media-v3\KVM-r1-media-v3.zip', 31),
    @('assets\audio_manifest.json', 'build\audio-pack\audio-v1\KVM-audio-v1.zip', 8)
)) {
    $manifest = Get-Content -LiteralPath (Join-Path $projectRoot $pack[0]) -Raw -Encoding UTF8 | ConvertFrom-Json
    $archivePath = Join-Path $projectRoot $pack[1]
    if ((Get-Item -LiteralPath $archivePath).Length -ne $manifest.download.bytes -or
        (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $manifest.download.sha256) {
        throw ('Archive metadata mismatch: ' + $manifest.packId)
    }
    $expected = @{}
    foreach ($entry in $manifest.assets) {
        if ($expected.ContainsKey($entry.path)) { throw 'Duplicate manifest path' }
        $expected[$entry.path] = $entry
        $source = Join-Path $projectRoot $entry.path
        if ((Get-Item -LiteralPath $source).Length -ne $entry.bytes -or
            (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) {
            throw ('Source metadata mismatch: ' + $entry.path)
        }
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    $seen = @{}
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            $record = $expected[$entry.FullName]
            if (-not $record -or $seen.ContainsKey($entry.FullName) -or $entry.Length -ne $record.bytes) {
                throw ('Unexpected/duplicate ZIP entry: ' + $entry.FullName)
            }
            $seen[$entry.FullName] = $true
            $input = $entry.Open()
            $digest = [Security.Cryptography.SHA256]::Create()
            try {
                $hash = [BitConverter]::ToString($digest.ComputeHash($input)).Replace('-', '')
                if ($hash -ne $record.sha256) { throw ('ZIP entry hash mismatch: ' + $entry.FullName) }
            } finally { $digest.Dispose(); $input.Dispose() }
        }
    } finally { $archive.Dispose() }
    if ($seen.Count -ne $expected.Count -or $seen.Count -ne $pack[2]) { throw 'Pack file count mismatch' }
    Write-Output ('PASS ' + $manifest.packId + ': ' + $seen.Count + ' files, ZIP bytes/hash and every source/entry hash verified.')
}
