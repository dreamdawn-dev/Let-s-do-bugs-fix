$ErrorActionPreference = 'Stop'

$JAVA = 'C:\Users\666\bin\graalvm-jdk-21.0.9+7.1\bin\java.exe'
$minecraft = 'C:\Users\666\Desktop\.minecraft'
$libraries = Join-Path $minecraft 'libraries'
$patchJar = Join-Path $PSScriptRoot 'dist\letsdo-crashfix-1.0.0-mc1.20.1-forge.jar'
$smokeDir = Join-Path $PSScriptRoot 'smoke'

# 使用纯 ASCII 模式定位版本文件夹（文件夹名包含 CJK 字符，
# PS 5.1 无法正确读取无 BOM 的 UTF-8 脚本，因此避免 CJK 字面量）。
$versionDir = Get-ChildItem -LiteralPath (Join-Path $minecraft 'versions') -Directory |
    Where-Object {
        $m = Join-Path $_.FullName 'mods'
        (Get-ChildItem -LiteralPath $m -Filter '*meadow*1.3.25*.jar' -ErrorAction SilentlyContinue) -and
        (Get-ChildItem -LiteralPath $m -Filter '*bloomingnature*.jar' -ErrorAction SilentlyContinue) -and
        (Get-ChildItem -LiteralPath $m -Filter 'letsdo-API-*.jar' -ErrorAction SilentlyContinue) -and
        (Get-ChildItem -LiteralPath $m -Filter 'architectury-9.2.14*.jar' -ErrorAction SilentlyContinue)
    } | Select-Object -First 1
if (-not $versionDir) { throw 'Dreamdawn version folder not found' }

$versionJson = Get-ChildItem -LiteralPath $versionDir.FullName -Filter 'Dreamdawn*.json' |
    Select-Object -First 1
if (-not $versionJson) { throw 'Dreamdawn version json not found' }
$modsSrc = Join-Path $versionDir.FullName 'mods'

if (Test-Path $smokeDir) { Remove-Item -LiteralPath $smokeDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $smokeDir 'mods'), (Join-Path $smokeDir 'natives') | Out-Null

$modsToCopy = @(
    (Get-ChildItem -LiteralPath $modsSrc -Filter 'architectury-9.2.14*.jar' | Select-Object -First 1),
    (Get-ChildItem -LiteralPath $modsSrc -Filter 'letsdo-API-*.jar' | Select-Object -First 1),
    (Get-ChildItem -LiteralPath $modsSrc -Filter '*meadow*1.3.25*.jar' | Select-Object -First 1),
    (Get-ChildItem -LiteralPath $modsSrc -Filter '*bloomingnature*.jar' | Select-Object -First 1)
)
foreach ($f in $modsToCopy) {
    if (-not $f) { throw 'a required mod jar was not found in the mods folder' }
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $smokeDir 'mods') -Force
}
Copy-Item -LiteralPath $patchJar -Destination (Join-Path $smokeDir 'mods') -Force

Set-Content -LiteralPath (Join-Path $smokeDir 'eula.txt') -Value 'eula=true' -Encoding Ascii
Set-Content -LiteralPath (Join-Path $smokeDir 'server.properties') -Value @(
    'online-mode=false',
    'server-port=25599',
    'level-name=smoke_world',
    'level-type=minecraft:flat',
    'generate-structures=false',
    'motd=letsdo-crashfix smoke test',
    'max-tick-time=-1'
) -Encoding Ascii

$json = Get-Content -LiteralPath $versionJson.FullName -Raw | ConvertFrom-Json

$classpath = @()
foreach ($lib in $json.libraries) {
    if (-not $lib.name -or -not $lib.downloads) { continue }
    $artifact = $lib.downloads.artifact
    if (-not $artifact) { continue }
    $path = Join-Path $libraries ($artifact.path -replace '/', '\')
    if (Test-Path -LiteralPath $path) { $classpath += $path }
}

$sep = ';'
$subs = @{
    '${library_directory}' = $libraries
    '${classpath}' = ($classpath -join $sep)
    '${classpath_separator}' = $sep
    '${natives_directory}' = Join-Path $smokeDir 'natives'
    '${launcher_name}' = 'smoke'
    '${launcher_version}' = '1.0'
    '${version_name}' = 'smoke'
}

$jvmArgs = @()
foreach ($arg in $json.arguments.jvm) {
    if ($arg -is [string]) {
        $jvmArgs += $arg
    } elseif ($arg.rules -and $arg.value) {
        # 仅 macOS 的标志；Windows 上永远无效
        if ($arg.value -match 'XstartOnFirstThread') { continue }
        $allow = $false
        foreach ($rule in $arg.rules) {
            if ($rule.action -eq 'allow') { $allow = $true; break }
        }
        if ($allow) { $jvmArgs += $arg.value }
    }
}

$jvmArgs = $jvmArgs | ForEach-Object {
    $s = $_
    foreach ($k in $subs.Keys) { $s = $s.Replace($k, $subs[$k]) }
    $s
}

# 仅保留本地实际存在的模块路径条目。
$finalJvm = @()
for ($i = 0; $i -lt $jvmArgs.Count; $i++) {
    if ($jvmArgs[$i] -eq '-p') {
        $entries = @()
        foreach ($e in ($jvmArgs[$i + 1] -split $sep)) {
            if (Test-Path -LiteralPath $e) { $entries += $e }
        }
        if ($entries.Count -gt 0) {
            $finalJvm += '-p'
            $finalJvm += ($entries -join $sep)
        }
        $i++
    } else {
        $finalJvm += $jvmArgs[$i]
    }
}

$serverArgs = @(
    '--launchTarget', 'forgeserver',
    '--fml.forgeVersion', '47.4.20',
    '--fml.mcVersion', '1.20.1',
    '--fml.forgeGroup', 'net.minecraftforge',
    '--fml.mcpVersion', '20230612.114412',
    '--nogui'
)

$allArgs = $finalJvm + @('cpw.mods.bootstraplauncher.BootstrapLauncher') + $serverArgs

# 使用 @argfile 以规避 Windows 命令行长度限制。
$argFile = Join-Path $smokeDir 'jvm_args.txt'
Set-Content -LiteralPath $argFile -Value (($allArgs | ForEach-Object { '"' + $_ + '"' })) -Encoding Ascii

Push-Location $smokeDir
try {
    $out = Join-Path $smokeDir 'server.log'
    $proc = Start-Process -FilePath $JAVA -ArgumentList ('"@' + $argFile + '"') `
        -RedirectStandardOutput $out -RedirectStandardError (Join-Path $smokeDir 'server.err.log') `
        -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddMinutes(6)
    $done = $false
    while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
        Start-Sleep -Seconds 3
        if (Test-Path $out) {
            $text = Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue
            if ($text -match 'Done \(') { $done = $true; break }
        }
    }
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    $log = if (Test-Path $out) { Get-Content -LiteralPath $out } else { @() }
    "=== last 70 lines of server.log ==="
    $log | Select-Object -Last 70
    "=== stderr tail ==="
    if (Test-Path (Join-Path $smokeDir 'server.err.log')) {
        Get-Content -LiteralPath (Join-Path $smokeDir 'server.err.log') | Select-Object -Last 20
    }
    "=== RESULT: $($(if ($done) { 'SERVER_REACHED_DONE' } else { 'NOT_REACHED_DONE' })) ==="
} finally {
    Pop-Location
}