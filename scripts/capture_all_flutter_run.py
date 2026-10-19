import subprocess
import time
import os
import sys
from PIL import Image

FLUTTER = "/home/douqi/mydev/flutter/bin/flutter"
BASE_DIR = "/home/douqi/workspaces/nixiangwork/iec104serversimulator"

APPS = [
    {
        "name": "iec104_server",
        "cwd": f"{BASE_DIR}/iec104_server",
        "out": f"{BASE_DIR}/docs/images/screenshot_iec104_server.png",
        "match": "iec104_server",
        "click": (350, 250),
    },
    {
        "name": "iec104_client",
        "cwd": f"{BASE_DIR}/iec104_client",
        "out": f"{BASE_DIR}/docs/images/screenshot_iec104_client.png",
        "match": "iec104_client",
        "click": (350, 250),
    },
    {
        "name": "modbus_slave",
        "cwd": f"{BASE_DIR}/modbus_slave",
        "out": f"{BASE_DIR}/docs/images/screenshot_modbus_slave.png",
        "match": "modbus_slave",
        "click": (300, 220),
    },
    {
        "name": "modbus_master",
        "cwd": f"{BASE_DIR}/modbus_master",
        "out": f"{BASE_DIR}/docs/images/screenshot_modbus_master.png",
        "match": "modbus_master",
        "click": (300, 220),
    },
    {
        "name": "iec61850_server",
        "cwd": f"{BASE_DIR}/iec61850_server",
        "out": f"{BASE_DIR}/docs/images/screenshot_iec61850_server.png",
        "match": "iec61850_server",
        "click": (300, 220),
    },
    {
        "name": "iec61850_client",
        "cwd": f"{BASE_DIR}/iec61850_client",
        "out": f"{BASE_DIR}/docs/images/screenshot_iec61850_client.png",
        "match": "iec61850_client",
        "click": (300, 220),
    },
]

def capture_app(app):
    name = app["name"]
    cwd = app["cwd"]
    out_file = app["out"]
    match_str = app["match"]

    print(f"\n==========================================")
    print(f"Launching {name} via: flutter run -d linux")
    print(f"==========================================")

    # 1. Clean up old processes
    subprocess.run(["pkill", "-9", "-x", name], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-9", "-x", "flameshot"], stderr=subprocess.DEVNULL)
    time.sleep(1)

    # 2. Launch with flutter run -d linux
    env = os.environ.copy()
    env["GDK_BACKEND"] = "x11"
    proc = subprocess.Popen(
        [FLUTTER, "run", "-d", "linux"],
        cwd=cwd,
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    wid = None
    for attempt in range(45):
        time.sleep(1)
        try:
            wm_out = subprocess.check_output(["wmctrl", "-l"]).decode()
            for line in wm_out.splitlines():
                if match_str in line.lower():
                    wid = line.split()[0]
                    break
            if wid:
                print(f"Window found on attempt {attempt+1}: ID={wid}")
                break
        except Exception:
            pass

    if not wid:
        print(f"ERROR: Could not find window for {name}")
        proc.terminate()
        return False

    time.sleep(4)

    # 3. Query window geometry via xwininfo
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

    print(f"Window Geometry: X={x}, Y={y}, W={w}, H={h}")

    # 4. Bring window to front
    subprocess.run(["wmctrl", "-i", "-a", wid])
    time.sleep(1)

    # Click inside to activate / select content
    if "click" in app and app["click"]:
        cx, cy = app["click"]
        subprocess.run(["xdotool", "mousemove", str(x + cx), str(y + cy), "click", "1"])
        time.sleep(1)

    # 5. Capture full screen using flameshot
    tmp_path = f"/tmp/flameshot_run_{name}.png"
    if os.path.exists(tmp_path):
        os.remove(tmp_path)

    f_env = os.environ.copy()
    f_env["QT_QPA_PLATFORM"] = "wayland"
    res = subprocess.run(["flameshot", "full", "-p", tmp_path], env=f_env)
    print(f"Flameshot exit code: {res.returncode}")

    # 6. Quit flutter run cleanly
    try:
        proc.stdin.write("q")
        proc.stdin.flush()
        proc.wait(timeout=6)
    except Exception:
        proc.kill()
        subprocess.run(["pkill", "-9", "-x", name], stderr=subprocess.DEVNULL)

    # 7. Crop and save
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
        print(f"ERROR: Flameshot failed to generate {tmp_path}")
        return False

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    for app in APPS:
        if target and app["name"] != target:
            continue
        capture_app(app)
        time.sleep(2)
    print("\nAll screenshot captures completed!")
