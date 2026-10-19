import subprocess
import time
import os
import sys
from PIL import Image

TARGETS = [
    {
        "name": "iec104_server",
        "bin": "./iec104_server/build/linux/x64/release/bundle/iec104_server",
        "out": "docs/images/screenshot_iec104_server.png",
        "match": "iec104_server",
        "click": (350, 250),
    },
    {
        "name": "iec104_client",
        "bin": "./iec104_client/build/linux/x64/release/bundle/iec104_client",
        "out": "docs/images/screenshot_iec104_client.png",
        "match": "iec104_client",
        "click": (350, 250),
    },
    {
        "name": "modbus_slave",
        "bin": "./modbus_slave/build/linux/x64/release/bundle/modbus_slave",
        "out": "docs/images/screenshot_modbus_slave.png",
        "match": "modbus_slave",
        "click": (350, 250),
    },
    {
        "name": "modbus_master",
        "bin": "./modbus_master/build/linux/x64/release/bundle/modbus_master",
        "out": "docs/images/screenshot_modbus_master.png",
        "match": "modbus_master",
        "click": (350, 250),
    },
    {
        "name": "iec61850_client",
        "bin": "./iec61850_client/build/linux/x64/release/bundle/iec61850_client",
        "out": "docs/images/screenshot_iec61850_client.png",
        "match": "iec61850_client",
        "click": (300, 200),
    },
]

def capture(item):
    name = item["name"]
    bin_path = item["bin"]
    out_file = item["out"]
    match_str = item["match"]

    print(f"\n>>> Starting capture for: {name}")

    # Kill old
    subprocess.run(["pkill", "-9", "-x", name], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-9", "-x", "flameshot"], stderr=subprocess.DEVNULL)
    time.sleep(1)

    # Launch with GDK_BACKEND=x11
    env = os.environ.copy()
    env["GDK_BACKEND"] = "x11"
    proc = subprocess.Popen([bin_path], env=env)
    print(f"Launched {name} PID={proc.pid}")
    time.sleep(4)

    # Find window ID
    wid = None
    for attempt in range(10):
        try:
            wm_out = subprocess.check_output(["wmctrl", "-l"]).decode()
            for line in wm_out.splitlines():
                if match_str in line.lower():
                    wid = line.split()[0]
                    break
            if wid:
                break
        except Exception:
            pass
        time.sleep(1)

    if not wid:
        print(f"FAILED to find window for {name}")
        proc.terminate()
        return False

    # Get xwininfo geometry
    info = subprocess.check_output(["xwininfo", "-id", wid]).decode()
    x, y, w, h = 0, 0, 0, 0
    for l in info.splitlines():
        if "Absolute upper-left X:" in l:
            x = int(l.split(":")[1].strip())
        elif "Absolute upper-left Y:" in l:
            y = int(l.split(":")[1].strip())
        elif "Width:" in l:
            w = int(l.split(":")[1].strip())
        elif "Height:" in l:
            h = int(l.split(":")[1].strip())

    print(f"Window: ID={wid}, X={x}, Y={y}, W={w}, H={h}")

    # Focus
    subprocess.run(["wmctrl", "-i", "-a", wid])
    time.sleep(1)

    # Click inside
    cx, cy = item["click"]
    subprocess.run(["xdotool", "mousemove", str(x + cx), str(y + cy), "click", "1"])
    time.sleep(1)

    # Capture
    tmp_path = f"/tmp/flameshot_{name}.png"
    if os.path.exists(tmp_path):
        os.remove(tmp_path)

    f_env = os.environ.copy()
    f_env["QT_QPA_PLATFORM"] = "wayland"
    subprocess.run(["flameshot", "full", "-p", tmp_path], env=f_env)

    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()

    # Crop
    if os.path.exists(tmp_path):
        im = Image.open(tmp_path)
        box = (x, y, x + w, y + h)
        cropped = im.crop(box)
        os.makedirs(os.path.dirname(out_file), exist_ok=True)
        cropped.save(out_file)
        print(f"SUCCESS: Saved {out_file} (size: {cropped.size})")
        os.remove(tmp_path)
        return True
    else:
        print(f"ERROR: flameshot did not save {tmp_path}")
        return False

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    for item in TARGETS:
        if target and item["name"] != target:
            continue
        capture(item)
        time.sleep(2)
