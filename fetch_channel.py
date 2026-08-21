#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wert聊天室频道 - 实时数据抓取脚本（后端 py）
============================================
调用 `tencent-channel-cli` 拉取 QQ 频道公开数据，输出 data.json 供 index.html 渲染。

前置：
  1. 已安装并登录 tencent-channel-cli：npm install -g tencent-channel-cli && tencent-channel-cli login
  2. 运行本脚本前确保 CLI 登录态有效（tencent-channel-cli login status）

用法：
  python fetch_channel.py            # 生成 data.json
  python fetch_channel.py --count 20 # 控制拉取帖子条数

可配合定时任务（cron / GitHub Actions）周期运行，实现数据"实时"刷新。
"""

import subprocess
import json
import sys
import os
import argparse

# ============ 频道配置 ============
GUILD_ID = "675225734090727394"        # wert聊天室频道 真实 ID（≠频道号 pd47256105）
GUILD_NUMBER = "pd47256105"
SHARE_URL = "https://pd.qq.com/s/g53fkmapy"
# ==================================

CLI_BASE = "tencent-channel-cli"


def resolve_cli():
    """Windows 下 npm 全局命令是 .cmd 包装器，Python subprocess 不会自动补扩展名，需探测。"""
    import shutil
    # shutil.which 在 Windows 会查 PATHEXT 里的扩展名
    found = shutil.which(CLI_BASE)
    if found:
        return found
    # 兜底：手动拼 .cmd（npm 全局常见于 Windows）
    for ext in (".cmd", ".ps1", ""):
        p = shutil.which(CLI_BASE + ext)
        if p:
            return p
    return CLI_BASE


CLI = resolve_cli()


def run(*args, **kwargs):
    """调用 CLI 并返回解析后的 JSON 字典。"""
    try:
        proc = subprocess.run(
            [CLI, *args, "--json"],
            capture_output=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError:
        sys.exit(f"[错误] 找不到 {CLI}，请先执行：npm install -g tencent-channel-cli")

    out = proc.stdout.strip()
    if not out:
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        # 非 JSON 输出（如限流提示），原样返回文本
        return {"_raw": out}


def get_guild_info():
    r = run("manage", "get-guild-info", "--guild-id", GUILD_ID)
    if not r or "data" not in r:
        return {}
    d = r["data"]
    return {
        "name": d.get("name", "wert聊天室频道"),
        "guild_number": d.get("guild_number", GUILD_NUMBER),
        "member_count": d.get("member_count", 0),
        "profile": d.get("profile", ""),
        "avatar_url": d.get("avatar_url", ""),
        "share_url": d.get("share_url", SHARE_URL),
        "guild_type": d.get("guild_type", ""),
        "create_time": d.get("create_time_human", ""),
    }


def get_feeds(count):
    r = run("feed", "get-guild-feeds", "--guild-id", GUILD_ID, "--get-type", "2", "--count", str(count))
    if not r or "data" not in r:
        return []
    return r["data"].get("feeds", [])


def get_feed_detail(feed_id, channel_id):
    r = run("feed", "get-feed-detail", "--feed-id", feed_id, "--guild-id", GUILD_ID)
    if not r or "data" not in r:
        return None
    return r["data"]


def get_comments(feed_id, channel_id):
    r = run("feed", "get-feed-comments", "--feed-id", feed_id, "--guild-id", GUILD_ID)
    if not r or "data" not in r:
        return []
    # 评论结构可能嵌套，取顶层 comments 列表
    d = r["data"]
    if isinstance(d, dict):
        return d.get("comments", [])
    return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=15, help="拉取帖子条数")
    args = parser.parse_args()

    print("[1/4] 拉取频道信息...")
    info = get_guild_info()
    if not info:
        print("[警告] 频道信息拉取失败，使用默认值。请检查 CLI 登录态。")

    print(f"[2/4] 拉取最新 {args.count} 条帖子...")
    feeds_raw = get_feeds(args.count)
    print(f"      获得 {len(feeds_raw)} 条帖子")

    print("[3/4] 补全帖子详情与评论...")
    feeds = []
    for i, f in enumerate(feeds_raw, 1):
        feed_id = f.get("feed_id", "")
        channel_id = f.get("channel_id", "")
        detail = get_feed_detail(feed_id, channel_id) or f
        content = detail.get("content") or detail.get("content_richtext", {}).get("text") or f.get("content_snippet", "")
        comments = get_comments(feed_id, channel_id)
        # 评论 content 可能是 richtext dict（含 text 字段）或纯字符串
        norm_comments = []
        for c in (comments or [])[:5]:
            c_content = c.get("content", "")
            if isinstance(c_content, dict):
                c_content = c_content.get("text", "")
            norm_comments.append({
                "author": c.get("author", ""),
                "content": c_content,
                "create_time": c.get("create_time", ""),
                "replies": c.get("replies_preview", []),
            })
        feeds.append({
            "feed_id": feed_id,
            "author": detail.get("author") or f.get("author", ""),
            "author_id": detail.get("author_id", ""),
            "channel_name": detail.get("channel_name") or f.get("channel_name", ""),
            "title": detail.get("title", ""),
            "content": content,
            "create_time": detail.get("create_time") or f.get("create_time", ""),
            "create_time_raw": detail.get("create_time_raw", 0),
            "comment_count": detail.get("comment_count", 0),
            "prefer_count": detail.get("prefer_count", 0),
            "share_url": detail.get("share_url", ""),
            "comments": norm_comments,
        })
        sys.stdout.write(f"\r      处理 {i}/{len(feeds_raw)}")
        sys.stdout.flush()
    print()

    print("[4/4] 写出 data.json...")
    payload = {
        "guild": info,
        "feeds": feeds,
        "updated_at": __import__("datetime").datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "source": "tencent-channel-cli",
    }
    with open(os.path.join(os.path.dirname(__file__), "data.json"), "w", encoding="utf-8") as fp:
        json.dump(payload, fp, ensure_ascii=False, indent=2)
    print("完成 ✅  data.json 已生成")


if __name__ == "__main__":
    main()
