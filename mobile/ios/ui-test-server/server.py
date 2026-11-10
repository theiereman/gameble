import http.server
import pathlib
import sys

CONFIGURATION = pathlib.Path(sys.argv[1]).read_bytes()
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


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body, kind = (CONFIGURATION, "application/json") if self.path.startswith("/configurations/") else (PAGE, "text/html")
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"GET {self.path} ({self.headers.get('User-Agent', '')[:40]})", flush=True)


http.server.ThreadingHTTPServer(("127.0.0.1", 3000), Handler).serve_forever()
