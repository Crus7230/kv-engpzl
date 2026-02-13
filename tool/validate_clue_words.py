#!/usr/bin/env python
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WORD_RE = re.compile(r"^[A-Z]+$")


def main() -> int:
    clue_path = Path("assets/wordlists/clue_words.json")
    if not clue_path.exists():
        print(f"Missing file: {clue_path}")
        return 1

    data = json.loads(clue_path.read_text(encoding="utf-8"))
    entries = data.get("entries")
    if not isinstance(entries, list):
        print("Invalid schema: entries must be a list.")
        return 1

    seen = set()
    bad = 0
    for i, item in enumerate(entries):
        if not isinstance(item, dict):
            print(f"[{i}] not an object")
            bad += 1
            continue
        word = str(item.get("word", "")).strip().upper()
        meaning = str(item.get("meaning", "")).strip()
        kor = str(item.get("korMeaning", "")).strip()
        pos = str(item.get("pos", "")).strip()

        if not WORD_RE.fullmatch(word):
            print(f"[{i}] invalid word: {word!r}")
            bad += 1
        if len(word) < 4 or len(word) > 8:
            print(f"[{i}] unusual length ({len(word)}): {word}")
            bad += 1
        if not meaning:
            print(f"[{i}] missing meaning: {word}")
            bad += 1
        if not kor:
            print(f"[{i}] missing korMeaning: {word}")
            bad += 1
        if not pos:
            print(f"[{i}] missing pos: {word}")
            bad += 1
        if word in seen:
            print(f"[{i}] duplicate word: {word}")
            bad += 1
        seen.add(word)

    if bad > 0:
        print(f"Validation failed with {bad} issue(s).")
        return 1

    if len(entries) < 3000:
        print(f"Too small: clue_words has {len(entries)} entries (need >= 3000).")
        return 1

    anagram_path = Path("assets/wordlists/anagram_rounds.json")
    if not anagram_path.exists():
        print(f"Missing file: {anagram_path}")
        return 1

    anagram_data = json.loads(anagram_path.read_text(encoding="utf-8"))
    rounds = anagram_data.get("entries")
    if not isinstance(rounds, list):
        print("Invalid schema: anagram_rounds.entries must be a list.")
        return 1
    if len(rounds) < 1000:
        print(f"Too small: anagram_rounds has {len(rounds)} entries (need >= 1000).")
        return 1

    print(f"OK: clue_words={len(entries)}, anagram_rounds={len(rounds)} validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
