#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wert聊天室频道 - 零依赖实时 API 服务（真·实时后端）
====================================================
不依赖 fastapi/flask，仅用 Python 标准库。对外提供：
  GET /api/feeds?count=15   实时拉取频道数据（复用 fetch_channel.py 的逻辑）
  GET /api/health           健康检查
  GET /                      托管同目录的 index.html（可选）
  GET /data.json            托管同目录的 data.json（可选）

部署：
  - 本地：python api_server.py  → http://localhost:8000
  - Render 等云平台：绑定 $PORT，启动命令 python api_server.py
    （云端需解决 CLI 登录态：把本机 token 注入，或用官方机器人凭证，详见 README）

缓存：内存缓存 60s，避免每次请求都打 CLI 触发频限（retCode 153）。
"""

import os
import json
import threading
import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import fetch_channel as fc  # 复用已验证的 CLI 抓取函数

CACHE_TTL = 60  # 秒
_cache = {"data": None, "ts": 0}
_cache_lock = threading.Lock()


def build_payload(count):
    """聚合频道信息 + 帖子 + 评论，返回与 data.json 一致的结构。"""
    info = fc.get_guild_info()
    feeds_raw = fc.get_feeds(count)
    feeds = []
    for f in feeds_raw:
        feed_id = f.get("feed_id", "")
        channel_id = f.get("channel_id", "")
        detail = fc.get_feed_detail(feed_id, channel_id) or f
        content = (detail.get("content")
                   or detail.get("content_richtext", {}).get("text")
                   or f.get("content_snippet", ""))
        comments_raw = fc.get_comments(feed_id, channel_id)
        norm_comments = []
        for c in (comments_raw or [])[:5]:
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
    return {
        "guild": info,
        "feeds": feeds,
        "updated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "source": "tencent-channel-cli (live api)",
    }


def get_data(count):
    now = datetime.datetime.now().timestamp()
    with _cache_lock:
        if _cache["data"] and (now - _cache["ts"]) < CACHE_TTL:
            return _cache["data"]
    # 缓存未命中：重新拉取（锁外执行，避免长时间持锁）
    data = build_payload(count)
    with _cache_lock:
        _cache["data"] = data
        _cache["ts"] = datetime.datetime.now().timestamp()
    return data


class Handler(BaseHTTPRequestHandler):
    def _cors_headers(self):
        # 标准 CORS 头：允许任意来源跨域（含 GitHub Pages 域名）
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Max-Age", "86400")

    def _send_json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors_headers()
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        # 浏览器 CORS 预检：必须返回 204 + 头，否则跨域请求被拦截
        self.send_response(204)
        self._cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _send_file(self, path, ctype):
        try:
            with open(path, "rb") as f:
                body = f.read()
        except FileNotFoundError:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        route = parsed.path
        qs = parse_qs(parsed.query)

        # 文件类路由也补 CORS，便于直接当主页托管
        if route in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self._cors_headers()
            try:
                with open(os.path.join(os.path.dirname(__file__), "index.html"), "rb") as f:
                    body = f.read()
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except FileNotFoundError:
                self.send_error(404)
            return

        if route == "/api/health":
            return self._send_json({"ok": True, "ts": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")})

        if route == "/api/feeds":
            try:
                count = int(qs.get("count", ["15"])[0])
            except ValueError:
                count = 15
            count = max(1, min(count, 50))
            try:
                data = get_data(count)
                return self._send_json(data)
            except Exception as e:
                return self._send_json({"error": str(e)}, code=500)

        if route in ("/", "/index.html"):
            return self._send_file(os.path.join(os.path.dirname(__file__), "index.html"),
                                   "text/html; charset=utf-8")

        if route == "/data.json":
            return self._send_file(os.path.join(os.path.dirname(__file__), "data.json"),
                                   "application/json; charset=utf-8")

        self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # 静默日志


def main():
    port = int(os.environ.get("PORT", "8000"))
    host = os.environ.get("HOST", "0.0.0.0")
    srv = ThreadingHTTPServer((host, port), Handler)
    # 注意：Windows/云平台默认控制台可能是 GBK，emoji 会抛 UnicodeEncodeError，故用 ASCII
    print("[wert] live API server started at http://%s:%s" % (host, port))
    print("      /api/feeds  live data endpoint")
    print("      /           serve homepage (if index.html present)")
    print("      cache TTL = %ss" % CACHE_TTL)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")


if __name__ == "__main__":
    main()
