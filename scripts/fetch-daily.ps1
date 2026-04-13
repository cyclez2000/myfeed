# MyFeed 每日抓取脚本
# 功能：抓取所有订阅源的最新内容，保存为 JSON 数据

$ErrorActionPreference = "Stop"

# 设置数据库路径
$dataDir = Join-Path $PSScriptRoot ".." "data"
$dbPath = Join-Path $dataDir "feed.db"

# 确定 feed 命令路径
$feedCmd = "feed"
if (-not (Get-Command "feed" -ErrorAction SilentlyContinue)) {
    $goBinPath = Join-Path $env:USERPROFILE "go\bin\feed.exe"
    if (Test-Path $goBinPath) {
        $feedCmd = $goBinPath
    } else {
        Write-Host "✗ 找不到 feed 命令" -ForegroundColor Red
        exit 1
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyFeed 每日抓取" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查数据库是否存在
if (-not (Test-Path $dbPath)) {
    Write-Host "✗ 数据库文件不存在: $dbPath" -ForegroundColor Red
    Write-Host "  请先运行 .\scripts\setup.ps1 初始化项目" -ForegroundColor Red
    exit 1
}

# 2. 查看当前订阅源
Write-Host "[1/3] 当前订阅源:" -ForegroundColor Yellow
& $feedCmd get feeds --db $dbPath 2>&1 | Write-Host
Write-Host ""

# 3. 抓取内容
Write-Host "[2/3] 开始抓取..." -ForegroundColor Yellow
& $feedCmd fetch --db $dbPath 2>&1 | Write-Host
Write-Host ""

# 4. 获取最新条目并保存
Write-Host "[3/3] 保存条目数据..." -ForegroundColor Yellow

# 获取今日条目（JSON 格式）
$today = Get-Date -Format "yyyy-MM-dd"
$outputDir = Join-Path $PSScriptRoot ".." "data"
$outputFile = Join-Path $outputDir "entries-$today.json"

# 获取所有条目（限制最近 100 条）
$entriesJson = & $feedCmd get entries --db $dbPath -o json --limit 100 2>&1

# 保存到文件
$entriesJson | Out-File -FilePath $outputFile -Encoding utf8
Write-Host "  ✓ 已保存: $outputFile" -ForegroundColor Green

# 统计信息
try {
    $entries = $entriesJson | ConvertFrom-Json
    $entryCount = if ($entries -is [Array]) { $entries.Count } else { 1 }
    Write-Host "  ✓ 共 $entryCount 条条目" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ 无法解析条目数量" -ForegroundColor Yellow
}

# 显示最近 5 条条目
Write-Host ""
Write-Host "最近条目预览:" -ForegroundColor Yellow
& $feedCmd get entries --db $dbPath --limit 5 2>&1 | Write-Host

# 完成
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  抓取完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  运行 .\scripts\generate-report.ps1 生成 Markdown 日报" -ForegroundColor White
Write-Host ""
