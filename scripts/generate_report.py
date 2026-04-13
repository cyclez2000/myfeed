#!/usr/bin/env python3
"""
MyFeed 日报生成脚本
功能：读取 feed CLI 导出的 JSON 条目，生成 Markdown 格式日报
可选：使用 Google AI Studio Gemini 生成 AI 摘要
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

try:
    import google.generativeai as genai
    HAS_GEMINI = True
except ImportError:
    HAS_GEMINI = False


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


def generate_ai_summary(entries: list, api_key: str) -> str:
    """使用 Google AI Studio Gemini 生成 AI 摘要"""
    if not HAS_GEMINI or not api_key:
        return ""
    
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-2.0-flash')
        
        # 构建提示词
        titles = []
        for entry in entries[:20]:  # 最多取 20 条
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
    
    # 摘要（截断到 300 字符）
    summary = entry.get('summary') or entry.get('description', '暂无摘要')
    if len(summary) > 300:
        summary = summary[:300] + "..."
    
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
    print(f"共 {len(entries)} 条条目")
    
    if not entries:
        print("警告: 没有条目可生成报告", file=sys.stderr)
        sys.exit(0)
    
    # AI 摘要（如果配置了 API Key）
    api_key = os.environ.get("GOOGLE_API_KEY", "")
    ai_summary = ""
    if api_key and HAS_GEMINI:
        print("正在生成 AI 摘要...")
        ai_summary = generate_ai_summary(entries, api_key)
        if ai_summary:
            print("AI 摘要生成成功")
    
    # 生成 Markdown
    print("生成 Markdown 报告...")
    markdown = generate_markdown(entries, ai_summary)
    
    # 保存文件
    output_path.write_text(markdown, encoding='utf-8')
    print(f"已保存: {output_path}")


if __name__ == "__main__":
    main()
