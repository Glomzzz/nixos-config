#!/usr/bin/env python3

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "i18n" / "clavis_en_US.ts"
CJK_RE = re.compile(
    r"[\u3000-\u303f\u3400-\u4dbf\u4e00-\u9fff\uff00-\uffef]"
)


def catalog_messages(path: Path) -> tuple[ET.Element, dict[tuple[str, str], str]]:
    root = ET.parse(path).getroot()
    messages: dict[tuple[str, str], str] = {}
    for context in root.findall("context"):
        context_name = context.findtext("name") or ""
        for message in context.findall("message"):
            source = message.findtext("source") or ""
            translation = message.find("translation")
            translation_type = (
                translation.get("type", "") if translation is not None else ""
            )
            translated_text = (
                "".join(translation.itertext()) if translation is not None else ""
            )
            if translation_type:
                raise AssertionError(
                    f"{context_name}: {source!r} has type {translation_type!r}"
                )
            if translated_text == "":
                raise AssertionError(
                    f"{context_name}: {source!r} has no English translation"
                )
            if CJK_RE.search(translated_text):
                raise AssertionError(
                    f"{context_name}: {source!r} still translates to CJK text"
                )
            key = (context_name, source)
            if key in messages:
                raise AssertionError(f"duplicate translation key: {key!r}")
            messages[key] = translated_text
    return root, messages


def extracted_messages() -> dict[tuple[str, str], str]:
    lupdate = shutil.which("lupdate")
    if lupdate is None:
        raise AssertionError("lupdate is required for the catalog freshness check")

    sources = [
        ROOT / "Common",
        ROOT / "Components",
        ROOT / "Modules",
        ROOT / "Services",
        ROOT / "Widgets",
        ROOT / "AppShell.qml",
        ROOT / "shell.qml",
        ROOT / "controlcenter.qml",
    ]
    with tempfile.TemporaryDirectory(prefix="clavis-i18n-") as temp_dir:
        generated = Path(temp_dir) / "clavis_en_US.ts"
        result = subprocess.run(
            [
                lupdate,
                *(str(source) for source in sources),
                "-extensions",
                "qml,js",
                "-source-language",
                "en_US",
                "-target-language",
                "en_US",
                "-locations",
                "none",
                "-no-obsolete",
                "-silent",
                "-ts",
                str(generated),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout)
        _, messages = catalog_messages_without_translations(generated)
        return messages


def catalog_messages_without_translations(
    path: Path,
) -> tuple[ET.Element, dict[tuple[str, str], str]]:
    root = ET.parse(path).getroot()
    messages: dict[tuple[str, str], str] = {}
    for context in root.findall("context"):
        context_name = context.findtext("name") or ""
        for message in context.findall("message"):
            source = message.findtext("source") or ""
            messages[(context_name, source)] = source
    return root, messages


def check_direct_runtime_strings() -> None:
    runtime_files = [
        ROOT / "core" / "src" / "weather_map_provider.cpp",
        ROOT / "core" / "cli" / "src" / "commands" / "clipboard_command.cpp",
        ROOT / "assets" / "wlogout" / "layout_1",
        ROOT / "assets" / "wlogout" / "layout_2",
        ROOT / "Services" / "I18nService.qml",
    ]
    for path in runtime_files:
        if CJK_RE.search(path.read_text(encoding="utf-8")):
            raise AssertionError(f"CJK runtime text bypasses translation in {path}")

    lyrics_source = (
        ROOT / "scripts" / "media" / "lyrics_fetcher.py"
    ).read_text(encoding="utf-8")
    for fallback in re.findall(r'"text"\s*:\s*"([^"]*)"', lyrics_source):
        if CJK_RE.search(fallback):
            raise AssertionError("lyrics fallback contains CJK runtime text")


def main() -> int:
    root, committed = catalog_messages(CATALOG)
    if root.get("language") != "en_US":
        raise AssertionError("English catalog language must be en_US")

    generated = extracted_messages()
    missing = sorted(set(generated) - set(committed))
    stale = sorted(set(committed) - set(generated))
    if missing or stale:
        raise AssertionError(
            f"catalog is stale: {len(missing)} missing, {len(stale)} obsolete"
        )

    check_direct_runtime_strings()
    print(f"validated {len(committed)} finished English translations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
