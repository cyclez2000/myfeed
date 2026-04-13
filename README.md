# MyFeed - RSS Daily Digest

基于 [odysseus0/feed](https://github.com/odysseus0/feed) 的自动化 RSS 日报生成器，通过 GitHub Actions 定时运行。

## ✨ 特性

- ⏰ **定时执行** - 每天北京时间 09:00 自动抓取并生成日报
- 🌐 **网络无忧** - 运行在 GitHub Actions 上，无国内访问限制
- 🤖 **AI 摘要** - 可选 Google Gemini AI 自动生成内容摘要
- 📰 **Markdown 输出** - 结构化的每日摘要报告
- 📦 **开箱即用** - 下载预编译二进制，2秒安装

## 📁 项目结构

```
myfeed/
├── .github/
│   └── workflows/
│       └── rss-daily.yml      # GitHub Actions 工作流
├── feeds.opml                  # 订阅列表（OPML 格式）
├── scripts/
│   ├── generate_report.py     # Python 生成 Markdown 日报
│   └── requirements.txt       # Python 依赖
├── data/
│   └── entries.json           # 抓取的条目数据（自动生成）
└── output/
    └── daily/
        └── YYYY-MM-DD.md      # 每日摘要（自动生成）
```

## 🚀 快速开始

### 1. 添加订阅源

编辑 `feeds.opml`，添加你的 RSS 订阅：

```xml
<outline type="rss" xmlUrl="https://example.com/rss.xml" text="Example Feed" title="Example Feed"/>
```

### 2. 配置 AI 摘要（可选）

> ⚠️ **重要提示**：AI 摘要功能需要配置 API Key 才能启用！

在仓库 Settings → Secrets and variables → Actions 中添加：

| Secret | 说明 |
|--------|------|
| `GOOGLE_API_KEY` | Google AI Studio API Key |

获取 API Key: [aistudio.google.com](https://aistudio.google.com/)

**配置步骤**：
1. 访问 [Google AI Studio](https://aistudio.google.com/)
2. 登录你的 Google 账号
3. 点击 "Get API Key" 创建新的 API Key
4. 复制 API Key
5. 在你的 GitHub 仓库中，进入 Settings → Secrets and variables → Actions
6. 点击 "New repository secret"
7. Name 填写 `GOOGLE_API_KEY`，Value 粘贴你的 API Key
8. 点击 "Add secret" 保存

配置完成后，工作流将自动生成 AI 摘要。如果未配置，日报将不包含 AI 摘要部分。

### 3. 触发工作流

- **自动执行**: 每天 09:00 (北京时间)
- **手动触发**: Actions → RSS Daily Digest → Run workflow

## 📖 使用指南

### 本地测试

```bash
# 安装 feed CLI
curl -sL https://github.com/odysseus0/feed/releases/download/v0.2.0/feed_0.2.0_linux_amd64.tar.gz | tar xz
sudo mv feed /usr/local/bin/

# 导入订阅
feed import feeds.opml

# 抓取内容
feed fetch

# 导出条目
feed get entries -o json --limit 100 > data/entries.json

# 生成报告
pip install -r scripts/requirements.txt
python scripts/generate_report.py
```

### 查看日报

生成的日报位于 `output/daily/YYYY-MM-DD.md`

## ⚙️ 工作流说明

| 步骤 | 操作 |
|------|------|
| 1 | 下载预编译 feed CLI（~2秒） |
| 2 | 导入 OPML 订阅 |
| 3 | 抓取所有 RSS 源 |
| 4 | 导出条目为 JSON |
| 5 | Python 生成 Markdown 日报 |
| 6 | 自动 commit & push 到仓库 |

## 🔧 修改定时时间

编辑 `.github/workflows/rss-daily.yml`：

```yaml
schedule:
  - cron: '0 1 * * *'  # UTC 01:00 = 北京时间 09:00
```

[cron 换算工具](https://crontab.guru/)

## 📝 许可证

MIT License
