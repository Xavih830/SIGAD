"""Automated evidence screenshot generator (code, terminal, url) using Chrome headless + Pygments."""

import argparse
import html
import shutil
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import TextLexer, get_lexer_for_filename
from pygments.util import ClassNotFound

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]


def find_browser() -> str:
    for candidate in CHROME_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    for name in ("chrome", "google-chrome", "msedge"):
        found = shutil.which(name)
        if found:
            return found
    raise FileNotFoundError("Chrome/Edge headless executable not found.")


def render_html_to_png(html_content: str, out_png: Path, height: int = 900) -> None:
    out_png.parent.mkdir(parents=True, exist_ok=True)
    browser = find_browser()
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as tmp:
        tmp.write(html_content)
        tmp_path = Path(tmp.name)
    try:
        subprocess.run(
            [
                browser,
                "--headless=new",
                "--disable-gpu",
                f"--screenshot={out_png.resolve()}",
                f"--window-size=1400,{height}",
                "--hide-scrollbars",
                tmp_path.resolve().as_uri(),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        tmp_path.unlink(missing_ok=True)


def capture_code(ref: str, spec: str, out_png: Path, label: str) -> None:
    path_part, line_range = spec.split(":", 1)
    start_line, end_line = (int(x) for x in line_range.split("-", 1))
    sha = subprocess.check_output(["git", "rev-parse", "--short", ref], text=True).strip()
    source = subprocess.check_output(["git", "show", f"{ref}:{path_part}"], text=True, encoding="utf-8")
    lines = source.splitlines()
    snippet = "\n".join(lines[start_line - 1 : end_line])

    try:
        lexer = get_lexer_for_filename(path_part)
    except ClassNotFound:
        lexer = TextLexer()
    formatter = HtmlFormatter(linenos="table", linenostart=start_line, style="monokai", full=False)
    highlighted = highlight(snippet, lexer, formatter)
    css = formatter.get_style_defs(".highlight")
    now_str = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

    page = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body {{ margin:0; padding:20px; background:#1e1e1e; color:#e6e6e6; font-family:Consolas, monospace; }}
.header {{ background:#2b2b2b; border:1px solid #444; padding:10px 14px; margin-bottom:14px; border-radius:6px; font-size:13px; }}
.header span {{ margin-right:18px; color:#9cdcfe; }}
{css}
.highlight {{ font-size:13px; line-height:1.45; }}
.linenos {{ color:#858585; padding-right:12px; user-select:none; }}
</style></head><body>
<div class="header">
  <span><b>Archivo:</b> {html.escape(path_part)} ({start_line}-{end_line})</span>
  <span><b>Ref:</b> {html.escape(label or ref)} ({sha})</span>
  <span><b>Captura:</b> {html.escape(now_str)}</span>
</div>
{highlighted}
</body></html>"""
    height = max(500, min(1800, 140 + (end_line - start_line + 1) * 20))
    render_html_to_png(page, out_png, height=height)


def capture_terminal(command_label: str, input_file: Path | None, cmd: str | None, ref: str, out_png: Path) -> None:
    sha = subprocess.check_output(["git", "rev-parse", "--short", ref], text=True).strip()
    now_str = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    if input_file is not None:
        output_text = input_file.read_text(encoding="utf-8", errors="replace")
    elif cmd is not None:
        proc = subprocess.run(cmd, shell=True, text=True, capture_output=True, encoding="utf-8", errors="replace")
        output_text = (proc.stdout or "") + (proc.stderr or "")
    else:
        raise ValueError("Specify --input or --cmd")

    lines = output_text.splitlines()
    if len(lines) > 55:
        output_text = "\n".join(lines[:15] + ["... (salida truncada para vista resumida) ..."] + lines[-35:])

    page = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body {{ margin:0; padding:20px; background:#0d1117; color:#c9d1d9; font-family:Consolas, monospace; }}
.header {{ background:#161b22; border:1px solid #30363d; padding:10px 14px; margin-bottom:14px; border-radius:6px; font-size:13px; }}
.header span {{ margin-right:18px; color:#58a6ff; }}
pre {{ background:#161b22; border:1px solid #30363d; padding:14px; border-radius:6px; font-size:12.5px; line-height:1.45; white-space:pre-wrap; word-break:break-word; }}
</style></head><body>
<div class="header">
  <span><b>Comando:</b> {html.escape(command_label)}</span>
  <span><b>Ref:</b> {html.escape(ref)} ({sha})</span>
  <span><b>Captura:</b> {html.escape(now_str)}</span>
</div>
<pre>{html.escape(output_text)}</pre>
</body></html>"""
    height = max(550, min(1400, 180 + len(output_text.splitlines()) * 19))
    render_html_to_png(page, out_png, height=height)


def capture_url(url: str, out_png: Path, virtual_time_budget: int = 15000) -> None:
    out_png.parent.mkdir(parents=True, exist_ok=True)
    browser = find_browser()
    subprocess.run(
        [
            browser,
            "--headless=new",
            "--disable-gpu",
            f"--virtual-time-budget={virtual_time_budget}",
            f"--screenshot={out_png.resolve()}",
            "--window-size=1400,900",
            "--hide-scrollbars",
            url,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="SIGAD automated evidence capture")
    sub = parser.add_subparsers(dest="mode", required=True)

    p_code = sub.add_parser("code")
    p_code.add_argument("--ref", required=True)
    p_code.add_argument("--spec", required=True, help="path:start-end")
    p_code.add_argument("--out", required=True)
    p_code.add_argument("--label", default="")

    p_term = sub.add_parser("terminal")
    p_term.add_argument("--title", required=True)
    p_term.add_argument("--input")
    p_term.add_argument("--cmd")
    p_term.add_argument("--ref", default="HEAD")
    p_term.add_argument("--out", required=True)

    p_url = sub.add_parser("url")
    p_url.add_argument("--url", required=True)
    p_url.add_argument("--out", required=True)
    p_url.add_argument("--budget", type=int, default=15000)

    args = parser.parse_args()
    if args.mode == "code":
        capture_code(args.ref, args.spec, Path(args.out), args.label)
    elif args.mode == "terminal":
        capture_terminal(
            args.title,
            Path(args.input) if args.input else None,
            args.cmd,
            args.ref,
            Path(args.out),
        )
    elif args.mode == "url":
        capture_url(args.url, Path(args.out), virtual_time_budget=args.budget)


if __name__ == "__main__":
    main()
