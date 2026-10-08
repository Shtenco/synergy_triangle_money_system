import json
import urllib.request

class JsonHttp:
    def __init__(self, timeout: float = 15.0):
        self.timeout = timeout

    def post(self, url: str, payload: dict) -> dict:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            url,
            data=data,
            headers={"content-type": "application/json", "accept": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            return json.loads(r.read().decode())

    def get(self, url: str) -> dict:
        req = urllib.request.Request(url, headers={"accept": "application/json"})
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            return json.loads(r.read().decode())
