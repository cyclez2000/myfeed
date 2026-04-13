# MyFeed 初始化脚本
# 功能：检查环境、安装 feed CLI、初始化数据库、添加测试订阅

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyFeed 初始化脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 确定 feed 命令路径
function Get-FeedCmd {
    if (Get-Command "feed" -ErrorAction SilentlyContinue) {
        return "feed"
    }
    $goBinPath = Join-Path $env:USERPROFILE "go\bin\feed.exe"
    if (Test-Path $goBinPath) {
        return $goBinPath
    }
    return $null
}

$feedCmd = Get-FeedCmd

# 1. 检查 Go 环境
Write-Host "[1/5] 检查 Go 环境..." -ForegroundColor Yellow
try {
    $goVersion = go version 2>&1
    Write-Host "  ✓ 已安装: $goVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ 未检测到 Go 环境" -ForegroundColor Red
    Write-Host "  请先安装 Go: https://go.dev/dl/" -ForegroundColor Red
    exit 1
}

# 2. 安装 feed CLI
if ($feedCmd) {
    Write-Host ""
    Write-Host "[2/5] 检查 feed CLI..." -ForegroundColor Yellow
    try {
        $feedVersion = & $feedCmd --version 2>&1
        Write-Host "  ✓ feed 已安装: $feedVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ feed 安装但无法运行" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[2/5] 安装 feed CLI..." -ForegroundColor Yellow
    Write-Host "  正在安装 feed CLI..." -ForegroundColor Gray
    go install github.com/odysseus0/feed/cmd/feed@latest
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ feed CLI 安装成功" -ForegroundColor Green
        $feedCmd = Get-FeedCmd
        if (-not $feedCmd) {
            Write-Host "  提示: 请确保 `$env:USERPROFILE\go\bin 已添加到 PATH" -ForegroundColor Cyan
            Write-Host "  临时使用: `$env:FEED_CMD = `"$env:USERPROFILE\go\bin\feed.exe`"" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ✗ 安装失败，请检查网络或手动安装" -ForegroundColor Red
        exit 1
    }
}

# 3. 验证 feed 命令可用
Write-Host ""
Write-Host "[3/5] 验证 feed 命令..." -ForegroundColor Yellow
if ($feedCmd) {
    try {
        $feedVersion = & $feedCmd --version 2>&1
        Write-Host "  ✓ feed 版本: $feedVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ feed 命令不可用" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ feed 命令不可用" -ForegroundColor Red
    Write-Host "  运行命令: `$env:PATH += `";$env:USERPROFILE\go\bin`"" -ForegroundColor Red
    exit 1
}

# 4. 初始化数据库目录
Write-Host ""
Write-Host "[4/5] 初始化数据目录..." -ForegroundColor Yellow
$dataDir = Join-Path $PSScriptRoot ".." "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    Write-Host "  ✓ 创建数据目录: $dataDir" -ForegroundColor Green
} else {
    Write-Host "  ✓ 数据目录已存在" -ForegroundColor Green
}

# 设置环境变量
$env:FEED_DB = Join-Path $dataDir "feed.db"
$env:FEED_CMD = $feedCmd
Write-Host "  数据库路径: $env:FEED_DB" -ForegroundColor Gray
Write-Host "  feed 路径: $env:FEED_CMD" -ForegroundColor Gray

# 5. 添加测试订阅源
Write-Host ""
Write-Host "[5/5] 添加测试订阅源..." -ForegroundColor Yellow
$testFeedUrl = "https://imjuya.github.io/juya-ai-daily/rss.xml"

# 检查是否已存在该订阅
$existingFeedsRaw = & $feedCmd get feeds -o json 2>&1
$alreadyExists = $false
try {
    $existingFeeds = $existingFeedsRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($existingFeeds) {
        foreach ($f in $existingFeeds) {
            if ($f.url -eq $testFeedUrl -or $f.feed_url -eq $testFeedUrl) {
                $alreadyExists = $true
                break
            }
        }
    }
} catch {}

if ($alreadyExists) {
    Write-Host "  ✓ 测试订阅已存在: $testFeedUrl" -ForegroundColor Green
} else {
    Write-Host "  正在添加测试订阅..." -ForegroundColor Gray
    & $feedCmd add feed $testFeedUrl --db $env:FEED_DB 2>&1 | Write-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ 添加成功: $testFeedUrl" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ 添加失败，可能是网络问题或无效的 RSS 源" -ForegroundColor Yellow
    }
}

# 导出当前订阅列表到 OPML
Write-Host ""
Write-Host "导出订阅列表到 feeds.opml..." -ForegroundColor Yellow
$opmlFile = Join-Path $PSScriptRoot ".." "feeds.opml"
& $feedCmd export --db $env:FEED_DB 2>&1 | Out-File -FilePath $opmlFile -Encoding utf8
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 导出成功: $opmlFile" -ForegroundColor Green
} else {
    Write-Host "  ⚠ 导出失败" -ForegroundColor Yellow
}

# 完成
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  初始化完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 运行 .\scripts\fetch-daily.ps1 抓取内容" -ForegroundColor White
Write-Host "  2. 运行 .\scripts\generate-report.ps1 生成日报" -ForegroundColor White
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Cyan
Write-Host "  feed add <URL>        - 添加订阅源" -ForegroundColor White
Write-Host "  feed get feeds        - 查看订阅列表" -ForegroundColor White
Write-Host "  feed fetch            - 抓取所有订阅" -ForegroundColor White
Write-Host "  feed get entries      - 查看条目列表" -ForegroundColor White
Write-Host "  feed search '关键词'   - 搜索内容" -ForegroundColor White
Write-Host ""
