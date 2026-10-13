param(
    [Parameter(Mandatory = $true)][string]$BuildSource,
    [Parameter(Mandatory = $true)][string]$VersionName,
    [Parameter(Mandatory = $true)][int]$VersionCode
)

$ErrorActionPreference = 'Stop'
$releaseInputRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseBuildRoot = (Resolve-Path -LiteralPath $BuildSource).Path
$releaseAllowedBuildRoot = (Join-Path $releaseInputRoot 'build\logic-only-source') + [IO.Path]::DirectorySeparatorChar
if (-not $releaseBuildRoot.StartsWith($releaseAllowedBuildRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unexpected build source.'
}
if ($VersionName -notmatch '^\d+\.\d+\.\d+$' -or $VersionCode -lt 1) {
    throw 'Invalid release version.'
}
$releaseVerifiedInputs = 0
foreach ($releaseDirectory in @('lib', 'android', 'web', 'test', 'tool')) {
    foreach ($releaseFile in Get-ChildItem -LiteralPath (Join-Path $releaseInputRoot $releaseDirectory) -File -Recurse) {
        $releaseRelative = $releaseFile.FullName.Substring($releaseInputRoot.Length + 1)
        if ($releaseRelative -match '(^|[\\/])(build|\.gradle|\.dart_tool|\.cxx)([\\/]|$)' -or
            $releaseFile.Name -in @('key.properties', 'local.properties') -or
            $releaseFile.Extension -in @('.jks', '.keystore')) { continue }
        $releaseBuiltInput = Join-Path $releaseBuildRoot $releaseRelative
        if ((Get-FileHash -LiteralPath $releaseFile.FullName -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $releaseBuiltInput -Algorithm SHA256).Hash) {
            throw ('Build input differs from tested source: ' + $releaseRelative)
        }
        $releaseVerifiedInputs++
    }
}
$releasePubspec = Get-Content -LiteralPath (Join-Path $releaseInputRoot 'pubspec.yaml') -Raw -Encoding UTF8
$releaseExpectedPubspec = [regex]::Replace($releasePubspec, '(?m)^    - assets/(legacy|expedition|audio)/\r?\n', '')
if ($releaseExpectedPubspec -ne (Get-Content -LiteralPath (Join-Path $releaseBuildRoot 'pubspec.yaml') -Raw -Encoding UTF8)) {
    throw 'Unexpected release build profile.'
}
$releaseApk = Join-Path $releaseBuildRoot 'build\app\outputs\flutter-apk\app-release.apk'
$releaseBuildTools = 'C:\Users\crusl\AppData\Local\Android\sdk\build-tools\36.0.0'
$releaseSigning = & (Join-Path $releaseBuildTools 'apksigner.bat') verify --verbose --print-certs $releaseApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$releaseSigningText = $releaseSigning -join "`n"
if ($releaseSigningText -notmatch 'Verified using v2 scheme.*true' -or
    $releaseSigningText -notmatch 'Signer #1 certificate SHA-256 digest: 6e48b7c6164bedc2b0785f2247769b238ee2428c7e567c6362f80bd1f27d5c7b') {
    throw 'Existing signing certificate or v2 signature mismatch.'
}
$releaseBadging = & (Join-Path $releaseBuildTools 'aapt.exe') dump badging $releaseApk
if ($LASTEXITCODE -ne 0) { throw 'APK metadata inspection failed.' }
$releaseExpectedPackage = "package: name='com.crus7230.kvm.renewal' versionCode='$VersionCode' versionName='$VersionName'"
$releaseBadgingText = $releaseBadging -join "`n"
if (-not $releaseBadgingText.Contains($releaseExpectedPackage) -or
    $releaseBadgingText -notmatch "sdkVersion:'24'" -or
    $releaseBadgingText -notmatch "targetSdkVersion:'36'" -or
    $releaseBadgingText -notmatch "launchable-activity: name='com.crus7230.kvm.renewal.MainActivity'" -or
    $releaseBadgingText -notmatch 'android.hardware.screen.landscape') {
    throw 'Unexpected package, version, SDK, activity or orientation.'
}
$releaseAbiLine = ($releaseBadging | Where-Object { $_.StartsWith('native-code:') }) -join ''
foreach ($releaseAbi in @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
    if ($releaseAbiLine -notmatch ("'" + [regex]::Escape($releaseAbi) + "'")) {
        throw ('Required ABI missing: ' + $releaseAbi)
    }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$releaseArchive = [IO.Compression.ZipFile]::OpenRead($releaseApk)
try {
    if (@($releaseArchive.Entries | Where-Object { $_.FullName -match '^assets/flutter_assets/assets/(legacy|expedition|audio)/' }).Count -ne 0) {
        throw 'Retained image/audio unexpectedly embedded in APK.'
    }
    foreach ($releaseManifestName in @('asset_manifest.json', 'audio_manifest.json')) {
        $releaseEntry = $releaseArchive.GetEntry('assets/flutter_assets/assets/' + $releaseManifestName)
        if (-not $releaseEntry) { throw 'Download manifest missing from APK.' }
        $releaseStream = $releaseEntry.Open()
        $releaseHasher = [Security.Cryptography.SHA256]::Create()
        try {
            $releaseEmbeddedHash = [BitConverter]::ToString($releaseHasher.ComputeHash($releaseStream)).Replace('-', '')
            if ($releaseEmbeddedHash -ne (Get-FileHash -LiteralPath (Join-Path $releaseInputRoot ('assets\' + $releaseManifestName)) -Algorithm SHA256).Hash) {
                throw ('Manifest mismatch: ' + $releaseManifestName)
            }
        } finally { $releaseStream.Dispose(); $releaseHasher.Dispose() }
    }
} finally { $releaseArchive.Dispose() }
$releaseDigest = (Get-FileHash -LiteralPath $releaseApk -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseArtifactDirectory = Join-Path $releaseInputRoot 'build\deployment\artifacts'
New-Item -ItemType Directory -Path $releaseArtifactDirectory -Force | Out-Null
$releaseArtifact = Join-Path $releaseArtifactDirectory "KVM-R1-$VersionName-alpha.apk"
if (Test-Path -LiteralPath $releaseArtifact) {
    if ((Get-FileHash -LiteralPath $releaseArtifact -Algorithm SHA256).Hash.ToLowerInvariant() -ne $releaseDigest) {
        throw 'Existing artifact differs; nothing overwritten.'
    }
} else { Copy-Item -LiteralPath $releaseApk -Destination $releaseArtifact }
if ((Get-FileHash -LiteralPath $releaseArtifact -Algorithm SHA256).Hash.ToLowerInvariant() -ne $releaseDigest) {
    throw 'Artifact copy hash mismatch.'
}
Write-Output ('PASS tested build inputs: ' + $releaseVerifiedInputs + ' SHA256 matches; only retained asset declarations excluded.')
Write-Output "PASS APK v2 signature, existing certificate, package, version $VersionName/$VersionCode, Android SDK/ABIs and launch Activity."
Write-Output 'PASS APK retained image/audio files: 0; download manifests: 2 exact SHA256 matches.'
Write-Output ('Artifact: ' + $releaseArtifact)
Write-Output ('Bytes: ' + (Get-Item -LiteralPath $releaseArtifact).Length)
Write-Output ('SHA256: ' + $releaseDigest)
