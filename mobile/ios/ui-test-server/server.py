import collections
import http.server
import pathlib
import sys
import urllib.request

CONFIGURATION = pathlib.Path(sys.argv[1]).read_bytes()
SITE = "https://gameble.net"
ROWS = "".join(f'<div class="row">Row {n}</div>' for n in range(1, 41))
PAGE = f"""<!doctype html>
<html data-native-app>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script type="module">import "https://unpkg.com/@hotwired/turbo@8.0.13/dist/turbo.es2017-esm.js"</script>
<style>
body {{ background: #0b0f15; color: #c7d5e0; font: 16px monospace; margin: 0; padding: 72px 16px 16px; }}
.row {{ height: 80px; border: 2px solid #1f3346; margin: 0 0 10px; padding: 8px; }}
</style>
</head>
<body>{ROWS}</body>
</html>""".encode()

loads = collections.Counter()
mode = {"page": "plain"}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/__mode/"):
            mode["page"] = self.path.removeprefix("/__mode/")
            loads.clear()
            return self.answer(200, b"ok", "text/plain")
        if self.path.startswith("/__loads"):
            return self.answer(200, str(loads["/en"]).encode(), "text/plain")
        if self.path.startswith("/configurations/"):
            return self.answer(200, CONFIGURATION, "application/json")
        loads[self.path] += 1
        if mode["page"] == "site":
            return self.relay()
        self.answer(200, PAGE, "text/html")

    def relay(self):
        headers = {k: v for k, v in self.headers.items() if k.lower() in ("user-agent", "accept", "accept-language", "cookie")}
        try:
            with urllib.request.urlopen(urllib.request.Request(SITE + self.path, headers=headers), timeout=20) as reply:
                body = reply.read().replace(SITE.encode(), b"http://localhost:3000")
                self.answer(reply.status, body, reply.headers.get("Content-Type", "text/html"))
        except urllib.error.HTTPError as error:
            self.answer(error.code, error.read(), error.headers.get("Content-Type", "text/html"))

    def answer(self, status, body, kind):
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"{mode['page']} GET {self.path} {args[1] if len(args) > 1 else ''} ({self.headers.get('User-Agent', '')[:40]})", flush=True)


http.server.ThreadingHTTPServer(("127.0.0.1", 3000), Handler).serve_forever()
