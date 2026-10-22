import asyncio
import json
import urllib.request
import websockets

async def check_console():
    req = urllib.request.urlopen("http://127.0.0.1:64608/json/list")
    targets = json.loads(req.read().decode())
    flutter_page = None
    for t in targets:
        if t.get("type") == "page" and "localhost:64575" in t.get("url", ""):
            flutter_page = t
            break

    ws_url = flutter_page["webSocketDebuggerUrl"]
    async with websockets.connect(ws_url) as ws:
        msg_id = 1
        async def send(method, params=None):
            nonlocal msg_id
            m = {"id": msg_id, "method": method}
            if params:
                m["params"] = params
            msg_id += 1
            await ws.send(json.dumps(m))
            while True:
                resp = json.loads(await ws.recv())
                if resp.get("id") == m["id"]:
                    return resp

        # Enable Log, Console, Runtime
        await send("Log.enable")
        await send("Console.enable")
        await send("Runtime.enable")

        # Evaluate window location and document body
        res = await send("Runtime.evaluate", {
            "expression": "document.body.innerHTML"
        })
        print("Body innerHTML length:", len(res.get("result", {}).get("value", "")))
        print("Body preview:", res.get("result", {}).get("value", "")[:500])

        # Check console logs by reading window errors or evaluating
        eval_err = await send("Runtime.evaluate", {
            "expression": "window.__flutter_errors || (window.flutterConfiguration ? JSON.stringify(window.flutterConfiguration) : 'none')"
        })
        print("Flutter config/err:", eval_err)

        # Let's wait a couple of seconds and print any messages received from ws
        try:
            for _ in range(10):
                msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
                d = json.loads(msg)
                method = d.get("method", "")
                if "Console" in method or "Log" in method or "exceptionThrown" in method:
                    print("LOG EVENT:", d)
        except asyncio.TimeoutError:
            pass

asyncio.run(check_console())
