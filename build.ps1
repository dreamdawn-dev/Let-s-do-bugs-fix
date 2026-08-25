$ErrorActionPreference = 'Stop'

$JAVA_21_HOME = 'C:\Users\666\bin\graalvm-jdk-21.0.9+7.1'
$JAVAC = Join-Path $JAVA_21_HOME 'bin\javac.exe'
$JAR = Join-Path $JAVA_21_HOME 'bin\jar.exe'

$minecraft = 'C:\Users\666\Desktop\.minecraft'
$libraries = Join-Path $minecraft 'libraries'

$cp = @(
  (Join-Path $libraries 'net\minecraft\client\1.20.1-20230612.114412\client-1.20.1-20230612.114412-srg.jar'),
  (Join-Path $libraries 'it\unimi\dsi\fastutil\8.5.9\fastutil-8.5.9.jar'),
  (Join-Path $libraries 'org\spongepowered\mixin\0.8.5\mixin-0.8.5.jar'),
  (Join-Path $libraries 'net\minecraftforge\javafmllanguage\1.20.1-47.4.20\javafmllanguage-1.20.1-47.4.20.jar'),
  (Join-Path $libraries 'com\mojang\datafixerupper\6.0.8\datafixerupper-6.0.8.jar')
)

# The Let's Do jars are needed to compile the multi-target StorageBlockEntity
# mixin. Locate them by ASCII-only patterns to avoid CJK path issues in PS 5.1.
$letDoPatterns = @(
  '*vinery*1.4.41*.jar',
  '*meadow*1.3.25*.jar',
  '*bloomingnature*1.0.12*.jar',
  '*brewery*2.0.6*.jar',
  '*farm_and_charm*.jar',
  '*bakery*2.0.6*.jar',
  'letsdo-API-*.jar'
)
$letDoJars = foreach ($pat in $letDoPatterns) {
  Get-ChildItem -LiteralPath (Join-Path $minecraft 'versions') -Directory |
  ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'mods') -Filter $pat -ErrorAction SilentlyContinue } |
  Select-Object -First 1
}
foreach ($j in $letDoJars) {
  if ($j -and -not ($cp -contains $j.FullName)) { $cp += $j.FullName }
}

# Farmer's Delight is an optional dependency for the sprinkler compat mixin.
# If the jar is not found, that mixin simply won't compile; skip it.
$fdJar = Get-ChildItem -LiteralPath (Join-Path $minecraft 'versions') -Directory |
ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'mods') -Filter '*FarmersDelight*.jar' -ErrorAction SilentlyContinue } |
Select-Object -First 1
if ($fdJar) { $cp += $fdJar.FullName }

$log4j = Get-ChildItem (Join-Path $libraries 'org\apache\logging\log4j\log4j-api') `
  -Filter 'log4j-api-*.jar' -Recurse -ErrorAction SilentlyContinue |
Sort-Object Name -Descending | Select-Object -First 1
if ($log4j) { $cp += $log4j.FullName }

$srcDir = Join-Path $PSScriptRoot 'src\main\java'
$resDir = Join-Path $PSScriptRoot 'src\main\resources'
$outDir = Join-Path $PSScriptRoot 'build\classes'
$distDir = Join-Path $PSScriptRoot 'dist'
$jarName = 'letsdo-crashfix-1.0.3-mc1.20.1-forge.jar'
$jarPath = Join-Path $distDir $jarName

if (Test-Path (Join-Path $PSScriptRoot 'build')) { Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'build') -Recurse -Force }
New-Item -ItemType Directory -Force -Path $outDir, $distDir | Out-Null

$javaFiles = Get-ChildItem -LiteralPath $srcDir -Recurse -Filter '*.java' | Select-Object -ExpandProperty FullName

& $JAVAC --release 17 -encoding UTF-8 -proc:none -cp ($cp -join ';') -d $outDir @javaFiles
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }

Get-ChildItem -LiteralPath $resDir -Force | Copy-Item -Destination $outDir -Recurse -Force

# Mixin on Forge reads the mixin config list from the jar MANIFEST's
# "MixinConfigs" attribute (MixinPlatformAgentDefault), not from mods.toml.
$manifest = Join-Path $PSScriptRoot 'build\MANIFEST.MF'
Set-Content -LiteralPath $manifest -Value @(
  'Manifest-Version: 1.0',
  'Implementation-Title: letsdo_crashfix',
  'Implementation-Version: 1.0.3',
  'MixinConfigs: patchmod.mixins.json'
) -Encoding Ascii

Push-Location $outDir
try {
  & $JAR cfm $jarPath $manifest .
  if ($LASTEXITCODE -ne 0) { throw 'jar failed' }
}
finally {
  Pop-Location
}

Write-Host "Built: $jarPath"