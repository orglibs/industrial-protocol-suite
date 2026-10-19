import subprocess
import time
import os
import sys
from PIL import Image

APPS = [
    {
        "name": "iec104_server",
        "bin": "./iec104_server/build/linux/x64/release/bundle/iec104_server",
        "output": "docs/images/screenshot_iec104_server.png",
        "match": "iec104_server"
    },
    {
        "name": "iec104_client",
        "bin": "./iec104_client/build/linux/x64/release/bundle/iec104_client",
        "output": "docs/images/screenshot_iec104_client.png",
        "match": "iec104_client"
    },
    {
        "name": "modbus_slave",
        "bin": "./modbus_slave/build/linux/x64/release/bundle/modbus_slave",
        "output": "docs/images/screenshot_modbus_slave.png",
        "match": "modbus_slave"
    },
    {
        "name": "modbus_master",
        "bin": "./modbus_master/build/linux/x64/release/bundle/modbus_master",
        "output": "docs/images/screenshot_modbus_master.png",
        "match": "modbus_master"
    },
    {
        "name": "iec61850_server",
        "bin": "./iec61850_server/build/linux/x64/release/bundle/iec61850_server",
        "output": "docs/images/screenshot_iec61850_server.png",
        "match": "iec61850_server"
    },
    {
        "name": "iec61850_client",
        "bin": "./iec61850_client/build/linux/x64/release/bundle/iec61850_client",
        "output": "docs/images/screenshot_iec61850_client.png",
        "match": "iec61850_client"
    },
]

def capture_app(app_info):
    name = app_info["name"]
    bin_path = app_info["bin"]
    output_path = app_info["output"]
    match_str = app_info["match"]

    print(f"\n==========================================")
    print(f"Capturing screenshot for: {name}")
    print(f"==========================================")

    # 1. Clean up old processes
    subprocess.run(["pkill", "-9", "-x", name], stderr=subprocess.DEVNULL)
    time.sleep(1)

    # 2. Launch with GDK_BACKEND=x11
    env = os.environ.copy()
    env["GDK_BACKEND"] = "x11"
    proc = subprocess.Popen([bin_path], env=env)
    print(f"Launched {name} (PID: {proc.pid})")
    time.sleep(3)

    # 3. Find window via wmctrl
    wid, x, y, w, h = None, None, None, None, None
    for attempt in range(10):
        try:
            out = subprocess.check_output(["wmctrl", "-l", "-G"]).decode()
            for line in out.splitlines():
                if match_str in line.lower():
                    parts = line.split()
                    wid = parts[0]
                    x = int(parts[2])
                    y = int(parts[3])
                    w = int(parts[4])
                    h = int(parts[5])
                    break
            if wid:
                break
        except Exception as e:
            pass
        time.sleep(1)

    if not wid:
        print(f"ERROR: Could not find window for {name}")
        proc.terminate()
        return False

    print(f"Window found: ID={wid}, original pos=({x}, {y}), size=({w}x{h})")

    # 4. Minimize all windows to avoid overlap, then restore and focus our window
    subprocess.run(["wmctrl", "-k", "on"])
    time.sleep(1)
    subprocess.run(["wmctrl", "-i", "-a", wid])
    subprocess.run(["wmctrl", "-i", "-r", wid, "-b", "add,above"])
    subprocess.run(["wmctrl", "-i", "-r", wid, "-e", f"0,50,50,{w},{h}"])
    time.sleep(2)

    # Re-query window position after move
    out = subprocess.check_output(["wmctrl", "-l", "-G"]).decode()
    for line in out.splitlines():
        if match_str in line.lower():
            parts = line.split()
            x = int(parts[2])
            y = int(parts[3])
            w = int(parts[4])
            h = int(parts[5])
            break

    print(f"Updated Window pos=({x}, {y}), size=({w}x{h})")

    # Click on the first item in the list to open details inspector
    click_x = x + 250
    click_y = y + 160
    subprocess.run(["xdotool", "mousemove", str(click_x), str(click_y), "click", "1"])
    time.sleep(1)

    # 5. Capture full screen using flameshot
    tmp_shot = f"/tmp/flameshot_tmp_{name}.png"
    if os.path.exists(tmp_shot):
        os.remove(tmp_shot)

    f_env = os.environ.copy()
    f_env["QT_QPA_PLATFORM"] = "wayland"
    flameshot_proc = subprocess.run(["flameshot", "full", "-p", tmp_shot], env=f_env)
    print(f"Flameshot completed with exit code: {flameshot_proc.returncode}")

    # Terminate app process
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()

    # 6. Crop and save
    if os.path.exists(tmp_shot):
        im = Image.open(tmp_shot)
        # Ensure coordinates are within image bounds
        img_w, img_h = im.size
        crop_x = max(0, min(x, img_w - 10))
        crop_y = max(0, min(y, img_h - 10))
        crop_w = min(w, img_w - crop_x)
        crop_h = min(h, img_h - crop_y)

        cropped = im.crop((crop_x, crop_y, crop_x + crop_w, crop_y + crop_h))
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        cropped.save(output_path)
        print(f"SUCCESS: Saved {output_path} (size: {cropped.size})")
        os.remove(tmp_shot)
        return True
    else:
        print(f"ERROR: flameshot failed to generate {tmp_shot}")
        return False

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    for app in APPS:
        if target and app["name"] != target:
            continue
        success = capture_app(app)
        time.sleep(2)
