#!/usr/bin/env python3
"""Wrap untranslated Han-containing QML/JS string literals in qsTr()."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


HAN_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
TRANSLATION_PREFIX_RE = re.compile(
    r"(?:qsTr|qsTranslate|QT_TR_NOOP)\s*\(\s*$"
)
EXCLUDED_PARTS = {".git", "build", "node_modules"}


def translatable_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.suffix in {".qml", ".js"}
        and not any(part in EXCLUDED_PARTS for part in path.parts)
    )


def wrap_source(source: str) -> tuple[str, int]:
    output: list[str] = []
    index = 0
    wrapped = 0
    state = "code"

    while index < len(source):
        char = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""

        if state == "line_comment":
            output.append(char)
            index += 1
            if char == "\n":
                state = "code"
            continue

        if state == "block_comment":
            output.append(char)
            index += 1
            if char == "*" and following == "/":
                output.append(following)
                index += 1
                state = "code"
            continue

        if char == "/" and following == "/":
            output.extend((char, following))
            index += 2
            state = "line_comment"
            continue

        if char == "/" and following == "*":
            output.extend((char, following))
            index += 2
            state = "block_comment"
            continue

        if char not in {'"', "'"}:
            output.append(char)
            index += 1
            continue

        quote = char
        end = index + 1
        escaped = False
        while end < len(source):
            current = source[end]
            if escaped:
                escaped = False
            elif current == "\\":
                escaped = True
            elif current == quote:
                end += 1
                break
            end += 1

        literal = source[index:end]
        contents = literal[1:-1]
        prefix = source[:index]
        suffix = source[end:]
        already_wrapped = bool(TRANSLATION_PREFIX_RE.search(prefix))
        previous_code = prefix.rstrip()
        object_key = bool(re.match(r"\s*:", suffix)) and (
            previous_code.endswith("{") or previous_code.endswith(",")
        )

        if HAN_RE.search(contents) and not already_wrapped and not object_key:
            output.extend(("qsTr(", literal, ")"))
            wrapped += 1
        else:
            output.append(literal)
        index = end

    return "".join(output), wrapped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write changes; without this flag only report remaining literals",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    args = parser.parse_args()

    total = 0
    touched = 0
    for path in translatable_files(args.root):
        source = path.read_text(encoding="utf-8")
        rewritten, count = wrap_source(source)
        if count == 0:
            continue
        total += count
        touched += 1
        print(f"{path.relative_to(args.root)}: {count}")
        if args.apply:
            path.write_text(rewritten, encoding="utf-8")

    action = "wrapped" if args.apply else "remaining"
    print(f"{action}: {total} literals in {touched} files")
    return 1 if total > 0 and not args.apply else 0


if __name__ == "__main__":
    raise SystemExit(main())
