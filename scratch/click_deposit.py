import asyncio, json, urllib.request, websockets, base64

async def click_tab():
    req = urllib.request.urlopen('http://127.0.0.1:64608/json/list')
    targets = json.loads(req.read().decode())
    flutter_page = next(t for t in targets if t.get('type') == 'page' and 'localhost:64575' in t.get('url', ''))
    
    async with websockets.connect(flutter_page['webSocketDebuggerUrl']) as ws:
        msg_id = 1
        async def call(method, params=None):
            nonlocal msg_id
            m = {'id': msg_id, 'method': method}
            if params: m['params'] = params
            msg_id += 1
            await ws.send(json.dumps(m))
            while True:
                r = json.loads(await ws.recv())
                if r.get('id') == m['id']: return r

        # Evaluate window size
        size_res = await call('Runtime.evaluate', {'expression': '({w: window.innerWidth, h: window.innerHeight})', 'returnByValue': True})
        w = size_res['result']['result']['value']['w']
        h = size_res['result']['result']['value']['h']
        print(f"Window size: {w}x{h}")

        # The 'Scan Bin QR & Deposit' button is roughly at middle x, around y = 715 in 412x860 frame
        # Bottom 'Deposit' tab icon is roughly at x = 0.3 * w, y = h - 35
        # Let's dispatch mouse events to click the Deposit tab icon (x = int(w * 0.3), y = int(h - 35))
        click_x = int(w * 0.3)
        click_y = int(h - 35)
        print(f"Clicking Deposit tab at ({click_x}, {click_y})...")

        await call('Input.dispatchMouseEvent', {'type': 'mousePressed', 'x': click_x, 'y': click_y, 'button': 'left', 'clickCount': 1})
        await asyncio.sleep(0.1)
        await call('Input.dispatchMouseEvent', {'type': 'mouseReleased', 'x': click_x, 'y': click_y, 'button': 'left', 'clickCount': 1})

        await asyncio.sleep(2)

        # Capture screenshot
        shot = await call('Page.captureScreenshot', {'format': 'png'})
        img_bytes = base64.b64decode(shot['result']['data'])
        with open('/Users/virocchan/.gemini/antigravity-ide/brain/e43dce92-a25f-4b57-8f87-cd43a13373fd/scratch/flutter_deposit_tab.png', 'wb') as f:
            f.write(img_bytes)
        print("Captured /Users/virocchan/.gemini/antigravity-ide/brain/e43dce92-a25f-4b57-8f87-cd43a13373fd/scratch/flutter_deposit_tab.png")

asyncio.run(click_tab())
