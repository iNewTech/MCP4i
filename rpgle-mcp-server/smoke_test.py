"""Exercise the live RPGLE MCP CGI endpoint using only Python's standard library.

Run after deploying on IBM i, from a host with access to the loopback-only
endpoint (for example, through an SSH tunnel). This is not a simulator.
"""

import argparse
import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def send(url: str, payload: dict | str, *, origin: str | None = None):
    body = payload if isinstance(payload, str) else json.dumps(payload)
    headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",
        "MCP-Protocol-Version": "2025-11-25",
    }
    if origin:
        headers["Origin"] = origin
    request = Request(url, data=body.encode("utf-8"), headers=headers)
    try:
        with urlopen(request, timeout=15) as response:
            return response.status, response.read()
    except HTTPError as error:
        return error.code, error.read()


def expect_rpc(url: str, request: dict, expected_id):
    status, raw = send(url, request)
    assert status == 200, (status, raw)
    response = json.loads(raw)
    assert response["jsonrpc"] == "2.0", response
    assert response["id"] == expected_id, response
    return response


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="MCP endpoint, e.g. http://127.0.0.1:8088/mcp")
    args = parser.parse_args()

    init = expect_rpc(
        args.url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "rpgle-smoke-test", "version": "1.0"},
            },
        },
        1,
    )
    assert init["result"]["protocolVersion"] == "2025-11-25", init
    assert "tools" in init["result"]["capabilities"], init

    status, raw = send(args.url, {"jsonrpc": "2.0", "method": "notifications/initialized"})
    assert status == 202 and not raw, (status, raw)

    listed = expect_rpc(args.url, {"jsonrpc": "2.0", "id": "list-1", "method": "tools/list"}, "list-1")
    assert [tool["name"] for tool in listed["result"]["tools"]] == ["get_system_info"], listed

    called = expect_rpc(
        args.url,
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "get_system_info", "arguments": {}},
        },
        3,
    )
    result = called["result"]
    assert result["isError"] is False, result
    system = json.loads(result["content"][0]["text"])
    assert all(key in system for key in ("os_name", "os_version", "os_release", "host_name")), system

    missing = expect_rpc(
        args.url,
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "run_cl"}},
        4,
    )
    assert missing["error"]["code"] == -32602, missing

    malformed_status, malformed_raw = send(args.url, "{")
    assert malformed_status == 200, malformed_raw
    assert json.loads(malformed_raw)["error"]["code"] == -32700, malformed_raw

    forbidden_status, _ = send(
        args.url, {"jsonrpc": "2.0", "id": 5, "method": "ping"}, origin="https://attacker.example"
    )
    assert forbidden_status == 403, forbidden_status

    try:
        with urlopen(args.url, timeout=15) as response:
            get_status = response.status
    except HTTPError as error:
        get_status = error.code
    assert get_status == 405, get_status

    print("PASS: initialize, notification, list, live read, rejected tool, malformed JSON, Origin, GET")
    print("Observed system:", json.dumps(system, indent=2))


if __name__ == "__main__":
    main()
