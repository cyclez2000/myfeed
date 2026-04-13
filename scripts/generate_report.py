#!/usr/bin/env python3
"""
MyFeed 日报生成脚本
功能：读取 feed CLI 导出的 JSON 条目，生成 Markdown 格式日报
可选：使用 Google AI Studio Gemini 生成 AI 摘要
支持多种 LLM 后端（通过配置文件）
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# 尝试加载配置文件
SCRIPT_DIR = Path(__file__).parent.parent
CONFIG_PATH = SCRIPT_DIR / "config" / "digest-config.json"
LLM_CONFIG = None

if CONFIG_PATH.exists():
    try:
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            LLM_CONFIG = json.load(f)
    except Exception as e:
        print(f"警告：配置文件加载失败：{e}", file=sys.stderr)

# 导入 Gemini SDK（使用新的 google.genai API）
try:
    from google import genai
    from google.genai import types
    HAS_GEMINI = True
    GEMINI_LIB = "google-genai"
except ImportError:
    try:
        import google.generativeai as genai
        HAS_GEMINI = True
        GEMINI_LIB = "google-generativeai"
    except ImportError:
        HAS_GEMINI = False
        GEMINI_LIB = "none"


def load_entries(json_path: str) -> list:
    """加载条目 JSON 文件"""
    with open(json_path, 'r', encoding='utf-8') as f:
        entries = json.load(f)
    
    # 确保是列表格式
    if not isinstance(entries, list):
        if isinstance(entries, dict):
            entries = [entries]
        else:
            entries = []
    
    return entries


def filter_today_entries(entries: list, target_date: str) -> list:
    """按发布日期过滤条目，只取指定日期的条目（使用时区感知）"""
    today_entries = []
    for entry in entries:
        pub_date = entry.get('published_at', '')
        if pub_date:
            try:
                if isinstance(pub_date, (int, float)):
                    # Unix 时间戳 - 转换为北京时间（UTC+8）
                    dt = datetime.fromtimestamp(pub_date, tz=timezone.utc)
                    dt_beijing = dt.astimezone(timezone(datetime.timedelta(hours=8)))
                    entry_date = dt_beijing.strftime("%Y-%m-%d")
                else:
                    # ISO 8601: "2026-04-13T00:53:00Z"
                    dt = datetime.fromisoformat(str(pub_date).replace('Z', '+00:00'))
                    dt_beijing = dt.astimezone(timezone(datetime.timedelta(hours=8)))
                    entry_date = dt_beijing.strftime("%Y-%m-%d")
                if entry_date == target_date:
                    today_entries.append(entry)
            except (ValueError, OSError):
                pass
    return today_entries


def generate_ai_summary(entries: list, api_key: str) -> str:
    """使用 Google AI Studio Gemini 生成 AI 摘要"""
    if not HAS_GEMINI or not api_key:
        return ""
    
    try:
        # 使用新 API
        try:
            client = genai.Client(api_key=api_key)
            
            titles = []
            for entry in entries[:20]:
                title = entry.get('title', '无标题')
                summary = entry.get('summary', '')[:100]
                titles.append(f"- {title}: {summary}")
            
            prompt = f"""请为以下 RSS 资讯生成简洁的中文日报摘要（200字以内）：

{chr(10).join(titles)}

要求：
1. 提炼今天的核心主题和趋势
2. 用简洁的中文总结
3. 输出格式：先一句话总结，再分点列出关键内容"""
            
            response = client.models.generate_content(
                model='gemma-4-26b-a4b-it',
                contents=prompt
            )
            return response.text
        except Exception as e:
            # 回退到旧 API
            print(f"新 API 调用失败，尝试旧 API: {e}", file=sys.stderr)
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-2.0-flash')
            
            titles = []
            for entry in entries[:20]:
                title = entry.get('title', '无标题')
                summary = entry.get('summary', '')[:100]
                titles.append(f"- {title}: {summary}")
            
            prompt = f"""请为以下 RSS 资讯生成简洁的中文日报摘要（200字以内）：

{chr(10).join(titles)}

要求：
1. 提炼今天的核心主题和趋势
2. 用简洁的中文总结
3. 输出格式：先一句话总结，再分点列出关键内容"""
            
            response = model.generate_content(prompt)
            return response.text
    except Exception as e:
        print(f"AI 摘要生成失败: {e}", file=sys.stderr)
        return ""


def format_entry(entry: dict) -> str:
    """格式化单个条目为 Markdown"""
    title = entry.get('title', '无标题')
    link = entry.get('url') or entry.get('link', '#')

    # 处理发布时间
    published = "未知时间"
    published_at = entry.get('published_at')
    if published_at:
        try:
            # Unix 时间戳
            if isinstance(published_at, (int, float)):
                dt = datetime.fromtimestamp(published_at)
                published = dt.strftime("%Y-%m-%d %H:%M")
            else:
                # ISO 字符串
                dt = datetime.fromisoformat(str(published_at).replace('Z', '+00:00'))
                published = dt.strftime("%Y-%m-%d %H:%M")
        except (ValueError, OSError):
            published = str(published_at)

    # 优先使用 content_md（完整 Markdown 内容），其次 content_html，最后 summary
    full_content = entry.get('content_md') or entry.get('content_html')
    if full_content:
        # 有完整内容时，输出完整文章
        feed_title = entry.get('feed_title', '未知来源')
        return f"""### [{title}]({link})

- **来源**: {feed_title}
- **发布时间**: {published}

---

{full_content}

---
"""
    else:
        # 没有完整内容时，只显示摘要
        summary = entry.get('summary') or entry.get('description', '暂无摘要')
        if len(summary) > 500:
            summary = summary[:500] + "..."

        feed_title = entry.get('feed_title', '未知来源')
        return f"""### [{title}]({link})

- **来源**: {feed_title}
- **发布时间**: {published}
- **摘要**: {summary}

---
"""


def generate_markdown(entries: list, ai_summary: str = "") -> str:
    """生成完整的 Markdown 日报"""
    today = datetime.now().strftime("%Y-%m-%d")
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 按订阅源分组
    feed_groups = {}
    for entry in entries:
        feed_title = entry.get('feed_title', '未知来源')
        if feed_title not in feed_groups:
            feed_groups[feed_title] = []
        feed_groups[feed_title].append(entry)
    
    # 构建 Markdown
    md = f"""# 📰 MyFeed 每日摘要

> **日期**: {today}  
> **生成时间**: {now}  
> **条目数量**: {len(entries)}

---

"""
    
    # AI 摘要（如果有）
    if ai_summary:
        md += f"""## 🤖 AI 摘要

{ai_summary}

---

"""
    
    # 按订阅源输出内容
    for feed_name, feed_entries in feed_groups.items():
        md += f"## 📡 {feed_name}\n\n"
        
        for entry in feed_entries:
            md += format_entry(entry)
    
    # 统计信息
    md += f"""## 📊 统计信息

| 指标 | 数值 |
|------|------|
| 总条目数 | {len(entries)} |
| 订阅源数量 | {len(feed_groups)} |
| 生成时间 | {now} |

---

> 🤖 由 MyFeed 自动生成 | 基于 [odysseus0/feed](https://github.com/odysseus0/feed)
"""
    
    return md


def main():
    # 路径设置
    script_dir = Path(__file__).parent.parent
    data_dir = script_dir / "data"
    output_dir = script_dir / "output" / "daily"
    
    json_path = data_dir / "entries.json"
    today = datetime.now().strftime("%Y-%m-%d")
    output_path = output_dir / f"{today}.md"
    
    # 确保输出目录存在
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 检查输入文件
    if not json_path.exists():
        print(f"错误: 找不到 {json_path}", file=sys.stderr)
        sys.exit(1)
    
    # 加载条目
    print(f"加载条目: {json_path}")
    entries = load_entries(str(json_path))
    print(f"数据库中共 {len(entries)} 条条目")

    # 获取北京时间（UTC+8）的日期
    tz_beijing = timezone(datetime.timedelta(hours=8))
    now_beijing = datetime.now(tz_beijing)
    today = now_beijing.strftime("%Y-%m-%d")
    
    # 按发布日期过滤，只取今天的条目（使用时区感知）
    today_entries = filter_today_entries(entries, today)

    print(f"今天 ({today}) 新增 {len(today_entries)} 条条目")

    # 错误处理：如果今天没有新条目，生成"今日无新内容"报告
    if not today_entries:
        print("警告：今天没有新条目，生成空报告", file=sys.stderr)
        # 生成"今日无新内容"的 Markdown 报告
        markdown = f"""# 📰 MyFeed 每日摘要

> **日期**: {today}  
> **生成时间**: {now_beijing.strftime("%Y-%m-%d %H:%M:%S")}  
> **条目数量**: 0

---

## 📢 今日无新内容

今天没有新的 RSS 条目。请检查订阅源是否正常更新。

---

## 📊 统计信息

| 指标 | 数值 |
|------|------|
| 总条目数 | 0 |
| 订阅源数量 | 0 |
| 生成时间 | {now_beijing.strftime("%Y-%m-%d %H:%M:%S")} |

---

> 🤖 由 MyFeed 自动生成 | 基于 [odysseus0/feed](https://github.com/odysseus0/feed)
"""
        output_path.write_text(markdown, encoding='utf-8')
        print(f"已保存空报告：{output_path}")
        sys.exit(0)

    entries = today_entries

    
    # AI 摘要（如果配置了 API Key）
    api_key = os.environ.get("GOOGLE_API_KEY", "")
    ai_summary = ""
    print(f"DEBUG: HAS_GEMINI={HAS_GEMINI}, GEMINI_LIB={GEMINI_LIB}, api_key_len={len(api_key) if api_key else 0}", file=sys.stderr)
    if api_key and HAS_GEMINI:
        print("正在生成 AI 摘要...", file=sys.stderr)
        ai_summary = generate_ai_summary(entries, api_key)
        if ai_summary:
            print("AI 摘要生成成功", file=sys.stderr)
        else:
            print("AI 摘要为空", file=sys.stderr)
    elif not api_key:
        print("警告: GOOGLE_API_KEY 未设置，跳过 AI 摘要", file=sys.stderr)
    
    # 生成 Markdown
    print("生成 Markdown 报告...")
    markdown = generate_markdown(entries, ai_summary)
    
    # 保存文件
    output_path.write_text(markdown, encoding='utf-8')
    print(f"已保存: {output_path}")


if __name__ == "__main__":
    main()
