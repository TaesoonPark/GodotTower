#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from queue import Empty, Queue

from PIL import Image
from Xlib import X, display
from Xlib.ext import xtest
from Xlib import XK
from Xlib.xobject.drawable import Window


ROOT_DIR = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT_DIR / "artifacts" / "gui-playtest"
WINDOW_TITLE = os.environ.get("GUI_PLAYTEST_WINDOW_TITLE", "ColonySimPrototype")
BUILDING_ID = os.environ.get("GUI_PLAYTEST_BUILDING_ID", "Campfire")
WINDOW_WIDTH = int(os.environ.get("GUI_PLAYTEST_WIDTH", "1920"))
WINDOW_HEIGHT = int(os.environ.get("GUI_PLAYTEST_HEIGHT", "1080"))
WINDOW_POS_X = int(os.environ.get("GUI_PLAYTEST_POS_X", "0"))
WINDOW_POS_Y = int(os.environ.get("GUI_PLAYTEST_POS_Y", "0"))
BOOT_WAIT_SEC = float(os.environ.get("GUI_PLAYTEST_BOOT_WAIT_SEC", "2.5"))
BUILD_TIMEOUT_SEC = float(os.environ.get("GUI_PLAYTEST_BUILD_TIMEOUT_SEC", "30"))


@dataclass
class Rect:
    x: int
    y: int
    width: int
    height: int


def resolve_godot_path() -> str:
    env_path = os.environ.get("GODOT_PATH", "")
    if env_path and os.access(env_path, os.X_OK):
        return env_path
    local_candidates = [
        ROOT_DIR / "tools" / "godot-linux" / "Godot_v4.6.1-stable_linux.x86_64",
        ROOT_DIR / "tools" / "godot-linux" / "Godot_linux.x86_64",
    ]
    for candidate in local_candidates:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    raise RuntimeError("Godot executable not found. Set GODOT_PATH or install the local Linux binary.")


def iter_windows(disp: display.Display, root: Window) -> list[Window]:
    stack = [root]
    out: list[Window] = []
    while stack:
        node = stack.pop()
        out.append(node)
        try:
            children = node.query_tree().children
        except Exception:
            continue
        stack.extend(children)
    return out


def get_window_title(disp: display.Display, win: Window) -> str:
    for getter in (win.get_wm_name,):
        try:
            title = getter()
        except Exception:
            title = None
        if title:
            return str(title)
    try:
        net_name = win.get_full_property(
            disp.intern_atom("_NET_WM_NAME"),
            disp.intern_atom("UTF8_STRING"),
        )
        if net_name and net_name.value:
            raw = net_name.value
            if isinstance(raw, bytes):
                return raw.decode("utf-8", errors="ignore")
            return str(raw)
    except Exception:
        pass
    return ""


def find_window(disp: display.Display, title_substring: str, timeout_sec: float = 15.0) -> Window:
    root = disp.screen().root
    deadline = time.time() + timeout_sec
    title_substring = title_substring.lower()
    while time.time() < deadline:
        for win in iter_windows(disp, root):
            title = get_window_title(disp, win)
            if title and title_substring in title.lower():
                return win
        time.sleep(0.2)
        disp.sync()
    raise RuntimeError(f"Window containing '{title_substring}' not found")


def absolute_geometry(disp: display.Display, win: Window) -> Rect:
    geom = win.get_geometry()
    translated = win.translate_coords(disp.screen().root, 0, 0)
    return Rect(translated.x, translated.y, geom.width, geom.height)


def move_mouse(disp: display.Display, x: int, y: int) -> None:
    xtest.fake_input(disp, X.MotionNotify, x=x, y=y)
    disp.sync()


def mouse_click(disp: display.Display, button: int, x: int, y: int, delay: float = 0.05) -> None:
    move_mouse(disp, x, y)
    time.sleep(delay)
    xtest.fake_input(disp, X.ButtonPress, button)
    xtest.fake_input(disp, X.ButtonRelease, button)
    disp.sync()


def mouse_drag(disp: display.Display, x1: int, y1: int, x2: int, y2: int, steps: int = 20) -> None:
    move_mouse(disp, x1, y1)
    time.sleep(0.05)
    xtest.fake_input(disp, X.ButtonPress, 1)
    disp.sync()
    for step in range(1, steps + 1):
        px = int(x1 + (x2 - x1) * step / steps)
        py = int(y1 + (y2 - y1) * step / steps)
        move_mouse(disp, px, py)
        time.sleep(0.01)
    xtest.fake_input(disp, X.ButtonRelease, 1)
    disp.sync()


def key_tap(disp: display.Display, key_name: str, delay: float = 0.05) -> None:
    keysym = XK.string_to_keysym(key_name)
    if keysym == 0:
        raise RuntimeError(f"Unknown keysym: {key_name}")
    keycode = disp.keysym_to_keycode(keysym)
    if keycode == 0:
        raise RuntimeError(f"Unknown keycode for: {key_name}")
    xtest.fake_input(disp, X.KeyPress, keycode)
    disp.sync()
    time.sleep(delay)
    xtest.fake_input(disp, X.KeyRelease, keycode)
    disp.sync()


def save_root_screenshot(disp: display.Display, path: Path) -> None:
    root = disp.screen().root
    width = disp.screen().width_in_pixels
    height = disp.screen().height_in_pixels
    raw = root.get_image(0, 0, width, height, X.ZPixmap, 0xFFFFFFFF)
    image = Image.frombytes("RGB", (width, height), raw.data, "raw", "BGRX")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def rel_to_abs(rect: Rect, x: int, y: int) -> tuple[int, int]:
    return rect.x + x, rect.y + y


def launch_game() -> subprocess.Popen[str]:
    godot_bin = resolve_godot_path()
    runtime_root = ROOT_DIR / ".godot-runtime"
    env = os.environ.copy()
    env.setdefault("XDG_DATA_HOME", str(runtime_root / "xdg-data"))
    env.setdefault("XDG_CONFIG_HOME", str(runtime_root / "xdg-config"))
    env["GUI_PLAYTEST_HINTS"] = "1"
    env["GUI_PLAYTEST_BUILDING_ID"] = BUILDING_ID
    Path(env["XDG_DATA_HOME"]).mkdir(parents=True, exist_ok=True)
    Path(env["XDG_CONFIG_HOME"]).mkdir(parents=True, exist_ok=True)
    cmd = [
        godot_bin,
        "--path",
        str(ROOT_DIR),
        "--windowed",
        "--single-window",
        "--resolution",
        f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}",
        "--position",
        f"{WINDOW_POS_X},{WINDOW_POS_Y}",
    ]
    return subprocess.Popen(
        cmd,
        cwd=str(ROOT_DIR),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )


def start_output_pump(process: subprocess.Popen[str], line_queue: Queue[str]) -> threading.Thread:
    def pump() -> None:
        assert process.stdout is not None
        for raw_line in process.stdout:
            line = raw_line.rstrip("\n")
            print(line)
            line_queue.put(line)

    thread = threading.Thread(target=pump, daemon=True)
    thread.start()
    return thread


def wait_for_line(
    line_queue: Queue[str],
    predicate: callable,
    timeout_sec: float,
) -> str:
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        remaining = max(0.1, deadline - time.time())
        try:
            line = line_queue.get(timeout=remaining)
        except Empty:
            continue
        if predicate(line):
            return line
    raise RuntimeError("Timed out waiting for expected GUI playtest output")


def parse_build_button_hint(line: str) -> tuple[int, int, int, int]:
    parts = line.split()
    if len(parts) != 6:
        raise RuntimeError(f"Unexpected build button hint: {line}")
    return tuple(int(parts[i]) for i in range(2, 6))


def parse_build_target_hint(line: str) -> tuple[int, int]:
    parts = line.split()
    if len(parts) != 4:
        raise RuntimeError(f"Unexpected build target hint: {line}")
    return int(parts[2]), int(parts[3])


def scenario_rts_smoke(disp: display.Display, rect: Rect) -> None:
    # Known initial positions from MainController._spawn_initial_colonists().
    colonist_1 = rel_to_abs(rect, 840, 480)
    move_target = rel_to_abs(rect, 1120, 640)
    drag_start = rel_to_abs(rect, 760, 400)
    drag_end = rel_to_abs(rect, 1010, 700)

    mouse_click(disp, 1, *colonist_1)
    time.sleep(0.25)
    mouse_click(disp, 3, *move_target)
    time.sleep(0.6)
    mouse_drag(disp, *drag_start, *drag_end)
    time.sleep(0.25)


def scenario_build_workstation(
    disp: display.Display,
    line_queue: Queue[str],
) -> None:
    key_tap(disp, "3")
    time.sleep(0.1)
    button_line = wait_for_line(
        line_queue,
        lambda line: line.startswith(f"GUI_HINT_BUILD_BUTTON {BUILDING_ID} "),
        10.0,
    )
    bx, by, bw, bh = parse_build_button_hint(button_line)
    mouse_click(disp, 1, bx + bw // 2, by + bh // 2)
    time.sleep(0.2)

    target_line = wait_for_line(
        line_queue,
        lambda line: line.startswith(f"GUI_HINT_BUILD_TARGET {BUILDING_ID} "),
        5.0,
    )
    tx, ty = parse_build_target_hint(target_line)
    mouse_click(disp, 1, tx, ty)
    wait_for_line(
        line_queue,
        lambda line: line == f"GUI_EVENT_BUILD_SITE_ADDED {BUILDING_ID}",
        5.0,
    )
    wait_for_line(
        line_queue,
        lambda line: line == f"GUI_EVENT_BUILD_COMPLETED {BUILDING_ID}",
        BUILD_TIMEOUT_SEC,
    )


def main() -> int:
    disp = display.Display()
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    process = launch_game()
    line_queue: Queue[str] = Queue()
    output_thread = start_output_pump(process, line_queue)
    try:
        time.sleep(BOOT_WAIT_SEC)
        win = find_window(disp, WINDOW_TITLE)
        rect = absolute_geometry(disp, win)
        try:
            save_root_screenshot(disp, ARTIFACT_DIR / "before.png")
        except Exception as exc:
            print(f"GUI_PLAYTEST_WARN: before screenshot skipped: {exc}")
        scenario_rts_smoke(disp, rect)
        scenario_build_workstation(disp, line_queue)
        try:
            save_root_screenshot(disp, ARTIFACT_DIR / "after.png")
        except Exception as exc:
            print(f"GUI_PLAYTEST_WARN: after screenshot skipped: {exc}")
        print(
            "GUI_PLAYTEST_PASS",
            f"window={rect.x},{rect.y} {rect.width}x{rect.height}",
            f"building={BUILDING_ID}",
            f"screenshots={ARTIFACT_DIR}",
        )
        return 0
    finally:
        try:
            process.terminate()
            process.wait(timeout=5)
        except Exception:
            process.kill()
        output_thread.join(timeout=1)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"GUI_PLAYTEST_FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
