#!/usr/bin/env python3
"""Attacker exfiltration endpoint (Act 2).

A deliberately dumb HTTP sink: any POST to /exfil is logged to
/data/exfil.log so the demo can show the stolen payload in the
transcript. It binds inside the container's docker network and is
exposed as localhost:8081 in the docker-compose file. It goes
nowhere. This file is part of the demo content, not tooling.
"""

import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = "/data/exfil.log"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", "replace")
        entry = {
            "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "path": self.path,
            "body": body,
        }
        with open(LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):  # silence default stderr noise
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()