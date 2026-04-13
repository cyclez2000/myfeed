# MyFeed 日报生成脚本
# 功能：读取当日抓取的条目，生成 Markdown 格式日报

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

$today = Get-Date -Format "yyyy-MM-dd"
$outputDir = Join-Path $PSScriptRoot ".." "output" "daily"
$outputFile = Join-Path $outputDir "$today.md"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyFeed 日报生成" -ForegroundColor Cyan
Write-Host "  日期: $today" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查数据库是否存在
if (-not (Test-Path $dbPath)) {
    Write-Host "✗ 数据库文件不存在: $dbPath" -ForegroundColor Red
    Write-Host "  请先运行 .\scripts\setup.ps1 初始化项目" -ForegroundColor Red
    exit 1
}

# 2. 创建输出目录
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# 3. 获取条目数据
Write-Host "[1/4] 获取条目数据..." -ForegroundColor Yellow

# 尝试读取当日 JSON 数据
$jsonFile = Join-Path $dataDir "entries-$today.json"
if (Test-Path $jsonFile) {
    Write-Host "  ✓ 使用当日抓取数据: entries-$today.json" -ForegroundColor Green
    $entriesJson = Get-Content $jsonFile -Raw -Encoding utf8
} else {
    Write-Host "  ⚠ 未找到当日 JSON，从数据库直接查询..." -ForegroundColor Yellow
    $entriesJson = & $feedCmd get entries --db $dbPath -o json --limit 100 2>&1
}

# 4. 解析条目
Write-Host ""
Write-Host "[2/4] 解析条目..." -ForegroundColor Yellow

try {
    $entries = $entriesJson | ConvertFrom-Json
    
    # 处理单个或多个条目
    if ($entries -isnot [Array]) {
        if ($entries) {
            $entries = @($entries)
        } else {
            $entries = @()
        }
    }
    
    $entryCount = $entries.Count
    Write-Host "  ✓ 共 $entryCount 条条目" -ForegroundColor Green
    
} catch {
    Write-Host "  ✗ 解析失败: $_" -ForegroundColor Red
    Write-Host "  可能还没有抓取内容，请先运行 .\scripts\fetch-daily.ps1" -ForegroundColor Yellow
    exit 1
}

# 检查是否有内容
if ($entryCount -eq 0) {
    Write-Host "  ⚠ 没有条目可生成报告" -ForegroundColor Yellow
    Write-Host "  请先运行 .\scripts\fetch-daily.ps1 抓取内容" -ForegroundColor Yellow
    exit 0
}

# 5. 生成 Markdown 报告
Write-Host ""
Write-Host "[3/4] 生成 Markdown 报告..." -ForegroundColor Yellow

# 开始构建 Markdown
$markdown = @"
# 📰 MyFeed 每日摘要

> **日期**: $today  
> **生成时间**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
> **条目数量**: $entryCount

---

"@

# 按订阅源分组
$feedGroups = @{}
foreach ($entry in $entries) {
    $feedTitle = if ($entry.feed_title) { $entry.feed_title } else { "未知来源" }
    if (-not $feedGroups.ContainsKey($feedTitle)) {
        $feedGroups[$feedTitle] = @()
    }
    $feedGroups[$feedTitle] += $entry
}

# 写入每个订阅源的内容
foreach ($feedName in $feedGroups.Keys) {
    $markdown += "## 📡 $feedName`n`n"
    
    $feedEntries = $feedGroups[$feedName]
    foreach ($entry in $feedEntries) {
        $title = if ($entry.title) { $entry.title } else { "无标题" }
        $link = if ($entry.url) { $entry.url } else { ($entry.link -or "#") }
        
        # 处理发布时间
        $published = "未知时间"
        if ($entry.published_at) {
            try {
                # Unix 时间戳（秒）
                $published = [DateTimeOffset]::FromUnixTimeSeconds([long]$entry.published_at).LocalDateTime.ToString("yyyy-MM-dd HH:mm")
            } catch {
                try {
                    # ISO 8601 字符串
                    $published = [DateTime]::Parse($entry.published_at).ToString("yyyy-MM-dd HH:mm")
                } catch {
                    $published = $entry.published_at
                }
            }
        }
        
        # 摘要（截断到 300 字符）
        $summary = "暂无摘要"
        if ($entry.summary) {
            $summaryText = $entry.summary
            if ($summaryText.Length -gt 300) {
                $summaryText = $summaryText.Substring(0, 300) + "..."
            }
            $summary = $summaryText
        } elseif ($entry.description) {
            $summaryText = $entry.description
            if ($summaryText.Length -gt 300) {
                $summaryText = $summaryText.Substring(0, 300) + "..."
            }
            $summary = $summaryText
        }
        
        $markdown += @"
### [$title]($link)

- **发布时间**: $published
- **摘要**: $summary

---

"@
    }
}

# 添加统计信息
$markdown += @"
## 📊 统计信息

| 指标 | 数值 |
|------|------|
| 总条目数 | $entryCount |
| 订阅源数量 | $($feedGroups.Count) |
| 生成时间 | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') |

---

> 🤖 由 MyFeed 自动生成 | 基于 [odysseus0/feed](https://github.com/odysseus0/feed)
"@

# 6. 保存文件
$markdown | Out-File -FilePath $outputFile -Encoding utf8
Write-Host "  ✓ 已保存: $outputFile" -ForegroundColor Green

# 7. 显示摘要
Write-Host ""
Write-Host "[4/4] 日报摘要:" -ForegroundColor Yellow
Write-Host "  📄 总条目: $entryCount" -ForegroundColor White
Write-Host "  📡 订阅源: $($feedGroups.Count)" -ForegroundColor White
Write-Host ""

# 完成
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  日报生成完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "查看报告: $outputFile" -ForegroundColor Cyan
Write-Host ""
