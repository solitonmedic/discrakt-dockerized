"""Check the real binary with local HTTP/IPC mocks and no desktop session."""

import contextlib
import http.server
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

BINARY = sys.argv.pop(1)


@contextlib.contextmanager
def app(directory, *, cli=False, address="127.0.0.1:18082"):
    env = os.environ.copy()
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "DISCRAKT_HEADLESS"):
        env.pop(key, None)
    env.update(
        HOME=str(directory),
        XDG_CONFIG_HOME=str(directory),
        XDG_RUNTIME_DIR=str(directory / "ipc"),
        DISCRAKT_SETUP_ADDR=address,
        RUST_LOG="info",
    )
    if not cli:
        env["DISCRAKT_HEADLESS"] = "1"
    args = [BINARY, "--headless"] if cli else [BINARY]
    with tempfile.TemporaryFile(mode="w+") as output:
        process = subprocess.Popen(args, env=env, stdout=output, stderr=subprocess.STDOUT)
        try:
            yield process, output
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    raise AssertionError("Discrakt did not stop on SIGTERM")


def read_exact(connection, length):
    data = b""
    while len(data) < length:
        chunk = connection.recv(length - len(data))
        if not chunk:
            raise EOFError
        data += chunk
    return data


class HeadlessChecks(unittest.TestCase):
    def test_setup_serves_embedded_ui_without_a_desktop(self):
        with tempfile.TemporaryDirectory() as temporary:
            with app(Path(temporary), cli=True) as (process, output):
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    self.assertIsNone(process.poll(), "Headless setup exited unexpectedly")
                    try:
                        with urllib.request.urlopen("http://127.0.0.1:18082/", timeout=1) as response:
                            body = response.read().decode()
                            self.assertEqual(response.status, 200)
                            self.assertIn('id="root"', body)
                            break
                    except (OSError, urllib.error.URLError):
                        time.sleep(0.1)
                else:
                    output.seek(0)
                    self.fail("Setup page did not start: " + output.read())
                self.assertFalse((Path(temporary) / "discrakt" / "credentials.ini").exists())

    def test_invalid_setup_address_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            with app(Path(temporary), address="invalid-address") as (process, _):
                self.assertNotEqual(process.wait(timeout=10), 0)

    def test_polling_and_discord_ipc_work_without_a_desktop(self):
        polled = threading.Event()
        connected = threading.Event()
        cleared = threading.Event()

        class IdlePlex(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path != "/status/sessions":
                    self.send_error(404)
                    return
                body = b'{"MediaContainer":{"Metadata":[]}}'
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                polled.set()

            def log_message(self, *_):
                pass

        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "ipc").mkdir()
            (directory / "discrakt").mkdir()
            with http.server.ThreadingHTTPServer(("127.0.0.1", 0), IdlePlex) as mock_http:
                threading.Thread(target=mock_http.serve_forever, daemon=True).start()
                config = directory / "discrakt" / "credentials.ini"
                config.write_text(
                    "[Discrakt]\nsource = plex\n[Plex]\n"
                    f"serverUrl = http://127.0.0.1:{mock_http.server_port}\n"
                    "token = local-test-placeholder\n"
                )
                with socket.socket(socket.AF_UNIX) as ipc:
                    ipc.bind(str(directory / "ipc" / "discord-ipc-0"))
                    ipc.listen()

                    def serve_ipc():
                        connection, _ = ipc.accept()
                        with connection:
                            try:
                                while True:
                                    opcode, length = struct.unpack("<II", read_exact(connection, 8))
                                    request = json.loads(read_exact(connection, length))
                                    if opcode == 0:
                                        connected.set()
                                        reply = {"cmd": "DISPATCH", "evt": "READY", "data": {}}
                                    elif opcode == 2:
                                        return
                                    else:
                                        self.assertEqual(request["cmd"], "SET_ACTIVITY")
                                        self.assertIsNone(request["args"].get("activity"))
                                        cleared.set()
                                        reply = {"cmd": request["cmd"], "nonce": request.get("nonce"), "data": {}}
                                    payload = json.dumps(reply).encode()
                                    connection.sendall(struct.pack("<II", 1, len(payload)) + payload)
                            except (EOFError, BrokenPipeError):
                                return

                    threading.Thread(target=serve_ipc, daemon=True).start()
                    with app(directory) as (process, output):
                        self.assertTrue(connected.wait(10), "Discord handshake did not occur")
                        self.assertTrue(polled.wait(25), "Configured source was not polled")
                        self.assertTrue(cleared.wait(5), "Idle activity was not cleared")
                        self.assertIsNone(process.poll())
                        output.seek(0)
                        self.assertIn("Discrakt is running headless", output.read())
                mock_http.shutdown()


if __name__ == "__main__":
    unittest.main()
