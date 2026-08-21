#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cloud_login_once.py (ASCII)
================================
云端首次部署时运行：生成 QQ 频道 CLI 登录二维码，
供手机扫码授权。授权成功后登录态自动保存在 ~/.qqcli ，
之后 api_server.py 即可正常调 CLI 拉取实时数据。

用法（云端 Linux）:
    python cloud_login_once.py
    # 终端会打印二维码(ASCII)并生成 ~/.qqcli/login-qrcode.png
    # 用手机 QQ 扫码授权；脚本自动轮询直到成功
    # 成功后 Ctrl+C 退出，之后启动 api_server.py 即可

依赖: tencent-channel-cli (npm i -g tencent-channel-cli)
"""
import os, sys, subprocess, time, shutil

def find_cli():
    cli = shutil.which("tencent-channel-cli") or shutil.which("tencent-channel-cli.cmd")
    if not cli:
        # 常见 npm 全局路径
        for cand in [
            "/usr/local/bin/tencent-channel-cli",
            os.path.expanduser("~/npm-global/bin/tencent-channel-cli"),
            os.path.expanduser("~/.npm-global/bin/tencent-channel-cli"),
        ]:
            if os.path.exists(cand):
                return cand
        raise SystemExit("未找到 tencent-channel-cli, 请先执行: npm i -g tencent-channel-cli")
    return cli

def main():
    cli = find_cli()
    qr_path = os.path.expanduser("~/.qqcli/login-qrcode.png")
    os.makedirs(os.path.dirname(qr_path), exist_ok=True)
    print("[login] 正在生成登录二维码...")
    # 1) 触发登录(生成授权二维码/链接)
    try:
        subprocess.run([cli, "login", "--json", "--qrcode-path", qr_path],
                       check=True, timeout=60)
    except subprocess.CalledProcessError as e:
        print("[login] 触发登录失败:", e)
        sys.exit(1)
    print("[login] 二维码已生成: " + qr_path)
    print("[login] 请用手机 QQ 扫码授权（下方也可尝试 ASCII 预览，或直接下载 PNG 查看）")
    # 2) 轮询等待授权完成
    print("[login] 开始轮询授权状态(最长10分钟)...")
    deadline = time.time() + 600
    while time.time() < deadline:
        try:
            r = subprocess.run([cli, "login", "poll-token", "--json"],
                               capture_output=True, text=True, timeout=30)
            out = r.stdout.strip()
            if r.returncode == 0 and out:
                print("[login] 授权成功! 登录态已保存到 ~/.qqcli")
                print("[login] 现在可以启动 api_server.py 了: python api_server.py")
                return
            else:
                print("[login] 等待扫码授权... (" + time.strftime("%H:%M:%S") + ")")
        except subprocess.CalledProcessError:
            print("[login] 等待中...")
        except subprocess.TimeoutExpired:
            pass
        time.sleep(5)
    print("[login] 超时未授权, 请重试。")

if __name__ == "__main__":
    main()
