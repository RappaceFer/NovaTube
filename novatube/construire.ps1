# NovaTube - construction de l'APK (c) 2026 Rappace
# Moteur : SmartTube de Yuriy Liskov (logiciel libre), variante F-Droid compilee depuis le code source.
# Usage :  powershell -ExecutionPolicy Bypass -File construire.ps1 [-MettreAJour]
#   -MettreAJour : recupere d'abord la derniere version du moteur SmartTube (quand YouTube change quelque chose)
param([switch]$MettreAJour)
$ErrorActionPreference = 'Stop'
$N = $PSScriptRoot                      # ...\NovaTube\novatube (notre surcouche)
$B = Split-Path $N                      # ...\NovaTube
$S = Join-Path $B 'src'                 # code SmartTube
$ID = 'com.rappace.novatube'
$JAVA = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$BT = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\35.0.0'
function Etape($t) { Write-Host "== $t" }
function G { & git.exe @args; if ($LASTEXITCODE) { throw "git $args" } }

if (!(Test-Path (Join-Path $S 'settings.gradle'))) {
    Etape 'Telechargement du code SmartTube'
    G clone -q --recurse-submodules https://github.com/yuliskov/SmartTube.git $S
}
Set-Location $S
Etape 'Remise a zero du code (garde les compilations precedentes pour aller plus vite)'
G checkout -q -- .
G clean -fdq
G submodule foreach -q --recursive "git checkout -q -- . && git clean -fdq"
if ($MettreAJour) {
    Etape 'Mise a jour du moteur SmartTube'
    G pull -q
    G submodule update -q --init --recursive
}
$rev = (& git log -1 --format=%h)

Etape 'Correctifs NovaTube (A propos, theme par defaut, aucun APK externe)'
Get-ChildItem (Join-Path $N 'patches') -Filter *.patch | ForEach-Object { G apply --whitespace=nowarn $_.FullName }

Etape 'Surcouche visuelle NovaTube'
Copy-Item (Join-Path $N 'res\*') (Join-Path $S 'smarttubetv\src\stfdroid\res') -Recurse -Force
function Remplace($f, $a, $b) {
    $p = Join-Path $S $f; $t = [IO.File]::ReadAllText($p)
    if (!$t.Contains($a)) { throw "introuvable dans ${f}: $a" }
    [IO.File]::WriteAllText($p, $t.Replace($a, $b), (New-Object Text.UTF8Encoding $false))
}
Remplace 'smarttubetv\build.gradle' 'applicationId "app.smarttube.fdroid"' "applicationId `"$ID`""
Remplace 'smarttubetv\src\stfdroid\res\values\strings.xml' 'SmartTube F-Droid' 'NovaTube'
Remplace 'leanbackassistant\src\stfdroid\res\xml\searchable.xml' 'app.smarttube.fdroid.search_provider' "$ID.search_provider"

Etape 'Signature (cle Rappace)'
$k = (Join-Path $B 'cle-de-signature\rappace-novatv.jks').Replace('\', '/')
$pw = (((Get-Content (Join-Path $B 'cle-de-signature\mot-de-passe.txt')) -match '^Mot de passe \(' | Select-Object -First 1) -replace '^[^:]*:\s*', '').Trim()
[IO.File]::WriteAllLines((Join-Path $S 'keystore.properties'), @("storeFile=$k", "storePassword=$pw", 'keyAlias=rappace', "keyPassword=$pw"))
[IO.File]::WriteAllLines((Join-Path $S 'local.properties'), @('sdk.dir=' + (Join-Path $env:LOCALAPPDATA 'Android\Sdk').Replace('\', '/')))

Etape 'Compilation (2 a 5 minutes)'
$env:JAVA_HOME = $JAVA
& .\gradlew.bat --no-daemon -q :smarttubetv:assembleStfdroidRelease
if ($LASTEXITCODE) { throw 'echec de la compilation' }

Etape 'Verifications'
$apk = Get-ChildItem 'smarttubetv\build\outputs\apk\stfdroid\release' -Filter '*universal.apk' | Select-Object -First 1
$badge = & (Join-Path $BT 'aapt2.exe') dump badging $apk.FullName
$ver = ([regex]'versionName=''([^'']+)''').Match(($badge -join "`n")).Groups[1].Value
if (-not (($badge -join "`n") -match "package: name='$ID'")) { throw 'identifiant inattendu' }
if (-not (($badge -join "`n") -match "application-label:'NovaTube'")) { throw 'nom inattendu' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead($apk.FullName)
$bad = @($z.Entries | Where-Object { $_.FullName -match 'alphasdk' }); $z.Dispose()
if ($bad.Count) { throw 'bibliotheque suspecte trouvee !' }
& (Join-Path $BT 'apksigner.bat') verify $apk.FullName 2>$null | Out-Null
if ($LASTEXITCODE) { throw 'signature invalide' }
$out = Join-Path $B "NovaTube-$ver.apk"
Copy-Item $apk.FullName $out -Force
Write-Host "OK : $out  (moteur SmartTube $rev, version $ver)"
