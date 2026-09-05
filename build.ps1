$ErrorActionPreference = 'Stop'

$JAVA_21_HOME = 'C:\Users\666\bin\graalvm-jdk-21.0.9+7.1'
$JAVAC = Join-Path $JAVA_21_HOME 'bin\javac.exe'
$JAR = Join-Path $JAVA_21_HOME 'bin\jar.exe'

$minecraft = 'C:\Users\666\Desktop\.minecraft'
$libraries = Join-Path $minecraft 'libraries'

$cp = @(
  (Join-Path $libraries 'net\minecraft\client\1.21.1-20240808.144430\client-1.21.1-20240808.144430-srg.jar'),
  (Join-Path $libraries 'net\neoforged\neoforge\21.1.248\neoforge-21.1.248-universal.jar'),
  (Join-Path $libraries 'net\neoforged\fancymodloader\loader\4.0.43\loader-4.0.43.jar'),
  (Join-Path $libraries 'org\spongepowered\mixin\0.8.7\mixin-0.8.7.jar'),
  (Join-Path $libraries 'it\unimi\dsi\fastutil\8.5.18\fastutil-8.5.18.jar'),
  (Join-Path $libraries 'com\mojang\datafixerupper\9.0.19\datafixerupper-9.0.19.jar')
)

# Let's Do 模组 jar 是编译多目标 StorageBlockEntity Mixin 所必需的。
# 使用纯 ASCII 模式匹配以规避 PS 5.1 的 CJK 路径问题。
$letDoPatterns = @(
  '*vinery*1.5*.jar',
  '*meadow*1.4*.jar',
  '*bakery*2.1*.jar',
  '*bloomingnature*1.0*.jar',
  '*wildernature*1.0*.jar',
  '*brewery*2.1*.jar'
)
$letDoJars = foreach ($pat in $letDoPatterns) {
  Get-ChildItem -LiteralPath (Join-Path $minecraft 'versions') -Directory |
  ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'mods') -Filter $pat -ErrorAction SilentlyContinue } |
  Select-Object -First 1
}
foreach ($j in $letDoJars) {
  if ($j -and -not ($cp -contains $j.FullName)) { $cp += $j.FullName }
}

$log4j = Get-ChildItem (Join-Path $libraries 'org\apache\logging\log4j\log4j-api') `
  -Filter 'log4j-api-*.jar' -Recurse -ErrorAction SilentlyContinue |
Sort-Object Name -Descending | Select-Object -First 1
if ($log4j) { $cp += $log4j.FullName }

$srcDir = Join-Path $PSScriptRoot 'src\main\java'
$resDir = Join-Path $PSScriptRoot 'src\main\resources'
$outDir = Join-Path $PSScriptRoot 'build\classes'
$distDir = Join-Path $PSScriptRoot 'dist'
$jarName = 'letsdo-crashfix-2.0.0-mc1.21.1-neoforge.jar'
$jarPath = Join-Path $distDir $jarName

if (Test-Path (Join-Path $PSScriptRoot 'build')) { Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'build') -Recurse -Force }
New-Item -ItemType Directory -Force -Path $outDir, $distDir | Out-Null

$javaFiles = Get-ChildItem -LiteralPath $srcDir -Recurse -Filter '*.java' | Select-Object -ExpandProperty FullName

& $JAVAC --release 21 -encoding UTF-8 -proc:none -cp ($cp -join ';') -d $outDir @javaFiles
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }

Get-ChildItem -LiteralPath $resDir -Force | Copy-Item -Destination $outDir -Recurse -Force

# NeoForge 的 Mixin 从 jar 的 MANIFEST.MF 中读取 "MixinConfigs" 属性。
$manifest = Join-Path $PSScriptRoot 'build\MANIFEST.MF'
Set-Content -LiteralPath $manifest -Value @(
  'Manifest-Version: 1.0',
  'Implementation-Title: letsdo_crashfix',
  'Implementation-Version: 2.0.0',
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