import asyncio, json, urllib.request, websockets, base64

async def click_and_capture():
    req = urllib.request.urlopen('http://127.0.0.1:64608/json/list')
    targets = json.loads(req.read().decode())
    flutter_page = next(t for t in targets if t.get('type') == 'page' and 'localhost:64575' in t.get('url', ''))
    
    async with websockets.connect(flutter_page['webSocketDebuggerUrl']) as ws:
        msg_id = 100
        async def call(method, params=None):
            nonlocal msg_id
            m = {'id': msg_id, 'method': method}
            if params: m['params'] = params
            msg_id += 1
            await ws.send(json.dumps(m))
            while True:
                raw = await ws.recv()
                data = json.loads(raw)
                if data.get('id') == m['id']:
                    return data

        # Click the green 'Scan Bin QR & Deposit' button (center x=200, y=475)
        print("Clicking 'Scan Bin QR & Deposit' button at (200, 475)...")
        await call('Input.dispatchMouseEvent', {'type': 'mousePressed', 'x': 200, 'y': 475, 'button': 'left', 'clickCount': 1})
        await asyncio.sleep(0.05)
        await call('Input.dispatchMouseEvent', {'type': 'mouseReleased', 'x': 200, 'y': 475, 'button': 'left', 'clickCount': 1})

        await asyncio.sleep(1.5)

        # Capture screenshot
        shot = await call('Page.captureScreenshot', {'format': 'png'})
        img_bytes = base64.b64decode(shot['result']['data'])
        out_path = '/Users/virocchan/.gemini/antigravity-ide/brain/e43dce92-a25f-4b57-8f87-cd43a13373fd/scratch/flutter_scanner_view.png'
        with open(out_path, 'wb') as f:
            f.write(img_bytes)
        print(f"Screenshot written to: {out_path}")

asyncio.run(click_and_capture())
