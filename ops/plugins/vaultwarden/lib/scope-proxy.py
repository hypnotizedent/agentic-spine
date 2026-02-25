#!/usr/bin/env python3
"""Scope-rewriting HTTPS reverse proxy for Bitwarden CLI <-> Vaultwarden.

Problem: bw v2026.1.0 hardcodes scope=api+offline_access in token requests.
         Vaultwarden only accepts scope=api, returning an error.
         Additionally, bw refuses non-HTTPS URLs (InsecureUrlNotAllowedError).

Solution: This proxy serves HTTPS on localhost with a self-signed cert,
          intercepts POST /identity/connect/token, rewrites the scope parameter,
          and forwards everything else unchanged to Vaultwarden via LAN.

Usage:
    python3 scope-proxy.py [--target URL] [--port PORT]

    --target   Vaultwarden endpoint (default: http://100.92.91.128:8081)
    --port     Local listen port (default: 0 = OS-assigned)

Outputs on startup (machine-parseable):
    proxy_url: https://127.0.0.1:<port>
    target: <url>
    pid: <pid>
    status: ready

Callers should set NODE_TLS_REJECT_UNAUTHORIZED=0 so bw accepts the self-signed cert.
"""

import http.server
import json
import os
import signal
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request


def parse_args(argv):
    target = "http://100.92.91.128:8081"
    port = 0
    i = 1
    while i < len(argv):
        if argv[i] == "--target" and i + 1 < len(argv):
            target = argv[i + 1]
            i += 2
        elif argv[i] == "--port" and i + 1 < len(argv):
            port = int(argv[i + 1])
            i += 2
        else:
            i += 1
    return target, port


TARGET, LISTEN_PORT = parse_args(sys.argv)

# For forwarding to the target (may or may not be HTTPS)
FORWARD_CTX = ssl.create_default_context()


def generate_self_signed_cert(tmpdir):
    """Generate a self-signed cert+key in tmpdir using openssl CLI."""
    cert_path = os.path.join(tmpdir, "cert.pem")
    key_path = os.path.join(tmpdir, "key.pem")
    subprocess.run(
        [
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", key_path, "-out", cert_path,
            "-days", "1", "-nodes",
            "-subj", "/CN=localhost",
            "-addext", "subjectAltName=IP:127.0.0.1",
        ],
        check=True,
        capture_output=True,
    )
    return cert_path, key_path


def _inject_decryption_options(body: bytes) -> bytes:
    """Inject UserDecryptionOptions into token response if missing.

    bw v2026.1.0 requires UserDecryptionOptions in the API-key login response.
    Vaultwarden doesn't include it. For standard master-password accounts,
    the field just indicates that a master password exists.
    """
    try:
        data = json.loads(body)
        if isinstance(data, dict) and "UserDecryptionOptions" not in data:
            data["UserDecryptionOptions"] = {
                "HasMasterPassword": True,
                "TrustedDeviceOption": None,
                "KeyConnectorOption": None,
            }
            return json.dumps(data).encode()
    except (json.JSONDecodeError, TypeError):
        pass
    return body


class ScopeProxy(http.server.BaseHTTPRequestHandler):
    """HTTPS handler that forwards requests, rewriting scope on token endpoint."""

    def _forward(self, method):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        # Rewrite scope for the token endpoint only
        if method == "POST" and self.path == "/identity/connect/token" and body:
            body = (
                body.replace(b"scope=api+offline_access", b"scope=api")
                .replace(b"scope=api%20offline_access", b"scope=api")
            )

        url = f"{TARGET}{self.path}"
        req = urllib.request.Request(url, data=body, method=method)

        # Forward headers, replacing Host
        target_host = urllib.parse.urlparse(TARGET).netloc
        for key, value in self.headers.items():
            lower = key.lower()
            if lower in ("host", "content-length", "transfer-encoding"):
                continue
            req.add_header(key, value)
        req.add_header("Host", target_host)
        if body is not None:
            req.add_header("Content-Length", str(len(body)))

        is_token_req = (method == "POST" and self.path == "/identity/connect/token")

        try:
            resp = urllib.request.urlopen(req, context=FORWARD_CTX, timeout=30)
            resp_body = resp.read()
            # Patch: inject UserDecryptionOptions if missing from token response.
            # bw v2026.1.0 requires this field; Vaultwarden doesn't provide it.
            if is_token_req and resp.status == 200:
                resp_body = _inject_decryption_options(resp_body)
            self._relay_response(resp.status, resp.getheaders(), resp_body)
        except urllib.error.HTTPError as e:
            self._relay_response(e.code, e.headers.items(), e.read())
        except Exception as e:
            self.send_error(502, f"Proxy error: {e}")

    def _relay_response(self, status, headers, body):
        self.send_response(status)
        skip = {"transfer-encoding", "connection", "content-length"}
        for key, value in headers:
            if key.lower() not in skip:
                self.send_header(key, value)
        # Always set correct Content-Length (body may have been patched)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self):
        self._forward("HEAD")

    def do_GET(self):
        self._forward("GET")

    def do_POST(self):
        self._forward("POST")

    def do_PUT(self):
        self._forward("PUT")

    def do_DELETE(self):
        self._forward("DELETE")

    def do_OPTIONS(self):
        self._forward("OPTIONS")

    def log_message(self, format, *args):
        # Suppress request logging (capabilities capture output)
        pass


def main():
    tmpdir = tempfile.mkdtemp(prefix="vw-scope-proxy-")
    cert_path, key_path = generate_self_signed_cert(tmpdir)

    server = http.server.HTTPServer(("127.0.0.1", LISTEN_PORT), ScopeProxy)

    # Wrap socket with TLS
    tls_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls_ctx.load_cert_chain(cert_path, key_path)
    server.socket = tls_ctx.wrap_socket(server.socket, server_side=True)

    actual_port = server.server_address[1]

    # Machine-parseable startup output
    print(f"proxy_url: https://127.0.0.1:{actual_port}")
    print(f"target: {TARGET}")
    print(f"pid: {os.getpid()}")
    print("status: ready")
    sys.stdout.flush()

    # Cleanup temp cert on exit
    def cleanup(*_):
        import shutil
        shutil.rmtree(tmpdir, ignore_errors=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    try:
        server.serve_forever()
    except SystemExit:
        server.server_close()
        import shutil
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    main()
