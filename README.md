# MyFeed - RSS 日报自动生成器

基于 [odysseus0/feed](https://github.com/odysseus0/feed) CLI + GitHub Actions 的自动化 RSS 日报系统。

## ✨ 特性

- ⏰ **定时执行** — 每天北京时间 09:00 自动抓取并生成日报
- 🌐 **网络无忧** — 运行在 GitHub Actions，无国内访问限制
- 📰 **完整文章** — 使用 `content_md` 字段，输出完整文章内容而非摘要
- 🤖 **AI 摘要** — 可选 Google Gemini AI 生成每日摘要
- 📦 **零维护** — 全自动，无需本地运行

## 📁 项目结构

```
myfeed/
├── .github/workflows/rss-daily.yml  # GitHub Actions 工作流
├── feeds.opml                       # 订阅列表（OPML 格式）
├── scripts/
│   ├── generate_report.py           # Python 生成 Markdown 日报
│   └── requirements.txt             # Python 依赖
├── output/daily/                    # 每日摘要输出目录
└── README.md
```

## 🚀 快速开始

### 1. 添加订阅源

编辑 `feeds.opml`，在 `<body>` 内添加：

```xml
<outline type="rss" xmlUrl="https://example.com/rss.xml" text="Example Feed" title="示例站点"/>
```

### 2. 配置 AI 摘要（可选）

在仓库 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 说明 |
|--------|------|
| `GOOGLE_API_KEY` | Google AI Studio API Key |

获取 API Key: [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

### 3. 触发工作流

- **自动执行**: 每天 09:00 (北京时间)
- **手动触发**: Actions → RSS Daily Digest → Run workflow

生成的日报位于 `output/daily/YYYY-MM-DD.md`

## 📡 当前订阅

| # | 订阅源 | 说明 |
|---|--------|------|
| 1 | 橘鸦AI早报 | 中文 AI 日报 |
| 2 | Hacker News (高分) | 科技热点（≥100 分） |
| 3 | Simon Willison | AI/Web 开发专家博客 |
| 4 | OpenAI 官方博客 | ChatGPT/GPT 系列动态 |
| 5 | Google AI 博客 | Gemini/DeepMind 等 |
| 6 | a16z Crypto | Web3/AI 投资趋势 |
| 7 | TechCrunch AI | AI 行业新闻 |

## ⚙️ 工作流说明

| 步骤 | 操作 | 耗时 |
|------|------|------|
| 1 | 下载预编译 feed CLI | ~2s |
| 2 | 导入 OPML 订阅 | ~1s |
| 3 | 抓取所有 RSS 源 | ~5s |
| 4 | 导出条目为 JSON | ~1s |
| 5 | Python 生成 Markdown 日报 | ~5s |
| 6 | 自动 commit & push | ~3s |

## 🔧 修改定时时间

编辑 `.github/workflows/rss-daily.yml`：

```yaml
schedule:
  - cron: '0 1 * * *'  # UTC 01:00 = 北京时间 09:00
```

[cron 换算工具](https://crontab.guru/)

## 📝 许可证

MIT License
