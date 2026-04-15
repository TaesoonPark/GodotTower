#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

TEXT_SUFFIXES = {
    ".cfg",
    ".gd",
    ".godot",
    ".ini",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".toml",
    ".tres",
    ".tscn",
    ".txt",
    ".yaml",
    ".yml",
}
TEXT_FILENAMES = {".editorconfig", ".gitattributes", ".gitignore"}
UTF8_BOM = b"\xef\xbb\xbf"


def git_list_paths(root_dir: Path, staged: bool) -> list[Path]:
    cmd = ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"] if staged else ["git", "ls-files", "-z"]
    result = subprocess.run(cmd, cwd=root_dir, capture_output=True, text=False, check=True)
    raw = result.stdout.decode("utf-8", errors="replace")
    if not raw:
        return []
    out: list[Path] = []
    for entry in raw.split("\0"):
        if not entry:
            continue
        out.append(Path(entry))
    return out


def should_check(path: Path) -> bool:
    return path.name in TEXT_FILENAMES or path.suffix.lower() in TEXT_SUFFIXES


def line_from_byte_offset(data: bytes, byte_offset: int) -> int:
    return data.count(b"\n", 0, byte_offset) + 1


def check_file(root_dir: Path, rel_path: Path) -> list[str]:
    errors: list[str] = []
    abs_path = root_dir / rel_path
    if not abs_path.exists() or not abs_path.is_file():
        return errors

    data = abs_path.read_bytes()
    if data.startswith(UTF8_BOM):
        errors.append(f"{rel_path.as_posix()}:1: UTF-8 BOM is not allowed")

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        line = line_from_byte_offset(data, exc.start)
        errors.append(
            f"{rel_path.as_posix()}:{line}: not valid UTF-8 (byte offset={exc.start})"
        )
        return errors

    for line_no, line in enumerate(text.splitlines(), start=1):
        if "\ufffd" in line:
            errors.append(
                f"{rel_path.as_posix()}:{line_no}: contains replacement character U+FFFD"
            )
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate repository text files with UTF-8 without BOM policy."
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--all", action="store_true", help="check all tracked text files")
    group.add_argument(
        "--staged",
        action="store_true",
        help="check only staged added/copied/modified/renamed files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root_dir = Path(__file__).resolve().parents[1]
    staged = args.staged
    if not args.all and not args.staged:
        staged = False

    try:
        candidates = git_list_paths(root_dir, staged=staged)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr.decode("utf-8", errors="replace"))
        return exc.returncode

    checked_count = 0
    all_errors: list[str] = []
    for rel_path in candidates:
        if not should_check(rel_path):
            continue
        checked_count += 1
        all_errors.extend(check_file(root_dir, rel_path))

    if all_errors:
        for line in all_errors:
            print(line)
        print(f"[encoding-check] FAIL ({len(all_errors)} issue(s), checked {checked_count} file(s))")
        return 1

    print(f"[encoding-check] PASS (checked {checked_count} file(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
