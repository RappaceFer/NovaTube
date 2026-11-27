# NovaTube Web : YouTube TV (youtube.com/tv) + moteur Firefox (GeckoView) + uBlock Origin integre.
# Telecharge les dernieres versions de GeckoView et uBlock Origin, compile, signe et verifie l'APK.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ici = Split-Path -Parent $MyInvocation.MyCommand.Path
$nt = "$env:USERPROFILE\Documents\NovaTube"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$env:JAVA_HOME = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Where-Object Name -like 'jdk-17*' | Select-Object -First 1).FullName
function Etape($t) { Write-Output "== $t" }
$utf8 = New-Object Text.UTF8Encoding($false)
Set-Location $ici

Etape 'Version de GeckoView (moteur Firefox)'
[xml]$meta = (Invoke-WebRequest -UseBasicParsing 'https://maven.mozilla.org/maven2/org/mozilla/geckoview/geckoview/maven-metadata.xml').Content
$gecko = $meta.metadata.versioning.release
Write-Output "GeckoView $gecko"

Etape 'uBlock Origin (derniere version officielle, addons.mozilla.org)'
$xpi = "$ici\ublock.xpi"
Invoke-WebRequest -UseBasicParsing 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi' -OutFile $xpi
$assets = "$ici\app\src\main\assets\ublock"
if (Test-Path $assets) { Remove-Item $assets -Recurse -Force }
New-Item -ItemType Directory -Force $assets | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($xpi, $assets)
$ub = (Get-Content "$assets\manifest.json" -Raw | ConvertFrom-Json).version
Write-Output "uBlock Origin $ub"

Etape 'Icone et banniere NovaTube'
$res = "$ici\app\src\main\res\mipmap-nodpi"
New-Item -ItemType Directory -Force $res | Out-Null
Copy-Item "$nt\novatube\res\mipmap-nodpi\app_icon.png", "$nt\novatube\res\mipmap-nodpi\app_banner.png" $res -Force

Etape 'Signature (cle Rappace) et outils'
$pw = ((Get-Content "$nt\cle-de-signature\mot-de-passe.txt" | Where-Object { $_ -match '^Mot de passe \(' } | Select-Object -First 1) -split ':\s*', 2)[1].Trim()
$alias = (& "$env:JAVA_HOME\bin\keytool.exe" -list -keystore "$nt\cle-de-signature\rappace-novatv.jks" -storepass $pw | Select-String 'PrivateKeyEntry' | Select-Object -First 1).Line.Split(',')[0].Trim()
$jks = ("$nt\cle-de-signature\rappace-novatv.jks").Replace('\', '/')
[IO.File]::WriteAllText("$ici\keystore.properties", "storeFile=$jks`nstorePassword=$pw`nkeyAlias=$alias`nkeyPassword=$pw`n", $utf8)
[IO.File]::WriteAllText("$ici\local.properties", "sdk.dir=" + $sdk.Replace('\', '/') + "`n", $utf8)
New-Item -ItemType Directory -Force "$ici\gradle\wrapper" | Out-Null
Copy-Item "$nt\src\gradle\wrapper\gradle-wrapper.jar" "$ici\gradle\wrapper\" -Force
Copy-Item "$nt\src\gradlew.bat" "$ici\" -Force
[IO.File]::WriteAllText("$ici\gradle\wrapper\gradle-wrapper.properties", "distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-bin.zip`ndistributionBase=GRADLE_USER_HOME`ndistributionPath=wrapper/dists`nzipStoreBase=GRADLE_USER_HOME`nzipStorePath=wrapper/dists`n", $utf8)

Etape 'Compilation (la premiere fois : 5 a 10 minutes)'
& "$ici\gradlew.bat" --no-daemon -q ":app:assembleRelease" "-PgeckoVersion=$gecko"
if ($LASTEXITCODE -ne 0) { throw 'Compilation echouee' }

Etape 'Verifications'
$apk = "$ici\app\build\outputs\apk\release\app-release.apk"
$bt = (Get-ChildItem "$sdk\build-tools" -Directory | Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } | Select-Object -Last 1).FullName
$badge = & "$bt\aapt2.exe" dump badging $apk
if (-not ($badge -match "package: name='com.rappace.novatube.web'")) { throw 'nom de paquet' }
& "$bt\apksigner.bat" verify $apk
if ($LASTEXITCODE -ne 0) { throw 'signature' }
$out = "$ici\NovaTube-Web.apk"
Copy-Item $apk $out -Force
Remove-Item $xpi -Force
Write-Output ("OK : $out  (GeckoView $gecko, uBlock Origin $ub, " + [math]::Round((Get-Item $out).Length / 1MB) + " Mo)")
