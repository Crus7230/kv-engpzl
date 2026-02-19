#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import urllib.error
import urllib.request
from pathlib import Path

HANGUL_RE = re.compile(r"[\uAC00-\uD7A3]")
PENDING_KOR = "Korean meaning pending"


def has_valid_korean(text: str) -> bool:
    value = str(text or "").strip()
    if not value:
        return False
    if value.lower() == PENDING_KOR.lower():
        return False
    return bool(HANGUL_RE.search(value))


def translate_text(url: str, text: str, timeout_seconds: float) -> str | None:
    payload = json.dumps(
        {
            "q": text,
            "source": "en",
            "target": "ko",
            "format": "text",
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            raw = response.read().decode("utf-8", errors="replace")
            data = json.loads(raw)
            translated = str(data.get("translatedText", "")).strip()
            if translated and has_valid_korean(translated):
                return translated
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("assets/wordlists/local_dictionary.json"),
    )
    parser.add_argument(
        "--translate-url",
        type=str,
        required=True,
        help="LibreTranslate-compatible endpoint URL. Example: http://127.0.0.1:5000/translate",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Maximum entries to update (0 means all).",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=8.0,
    )
    args = parser.parse_args()

    payload = json.loads(args.input.read_text(encoding="utf-8"))
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise SystemExit("Invalid local_dictionary.json: entries is not a list")

    updated = 0
    attempted = 0
    skipped = 0

    for row in entries:
        if not isinstance(row, dict):
            continue
        current_kor = str(row.get("korDefinition", "")).strip()
        if has_valid_korean(current_kor):
            skipped += 1
            continue
        definition = str(row.get("definition", "")).strip()
        if not definition:
            skipped += 1
            continue
        translation = translate_text(args.translate_url, definition, args.timeout_seconds)
        attempted += 1
        if translation:
            row["korDefinition"] = translation
            updated += 1
        if args.limit > 0 and updated >= args.limit:
            break

    payload["generatedBy"] = "tool/fill_local_kor_with_api.py"
    args.input.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("Filled local Korean meanings with API")
    print(f"- updated: {updated}")
    print(f"- attempted: {attempted}")
    print(f"- skipped_existing: {skipped}")
    print(f"- output: {args.input}")


if __name__ == "__main__":
    main()

