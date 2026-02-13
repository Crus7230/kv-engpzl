#!/usr/bin/env python
"""
Generate large, filtered English word pools for KE Games.

Requirements:
  - pip install wordfreq

Output files (assets/wordlists):
  - wordle_answers_4.txt
  - wordle_answers_5.txt
  - wordle_allowed_4.txt
  - wordle_allowed_5.txt
  - crash_words.txt
  - summary.txt

Policy:
  - Answers: common words only (top-N frequency slice)
  - Allowed: much broader, so obvious words rarely get rejected
  - Crash: 3~7 letter words from broad pool
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from wordfreq import top_n_list

ALPHA = re.compile(r"^[a-z]+$")

# High-confidence profanity/slur blacklist (small, maintainable).
BLACKLIST = {
    "anal",
    "anus",
    "arse",
    "boob",
    "boobs",
    "cunt",
    "dick",
    "faggot",
    "fuck",
    "fucks",
    "fucking",
    "nigger",
    "penis",
    "porn",
    "pussy",
    "rape",
    "raped",
    "rapes",
    "shit",
    "slut",
    "whore",
}


def normalize(words: list[str]) -> list[str]:
    out: list[str] = []
    seen = set()
    for raw in words:
        w = raw.strip().lower()
        if not ALPHA.fullmatch(w):
            continue
        if w in BLACKLIST:
            continue
        if w not in seen:
            seen.add(w)
            out.append(w)
    return out


def is_answer_friendly(word: str) -> bool:
    vowels = sum(1 for c in word if c in "aeiou")
    if vowels == 0:
        return False
    if re.search(r"(.)\1\1", word):
        return False
    return True


def pick_answers(freq_words: list[str], length: int) -> list[str]:
    out: list[str] = []
    for w in freq_words:
        if len(w) != length:
            continue
        if not is_answer_friendly(w):
            continue
        out.append(w.upper())
    return out


def to_sorted_upper_unique(words: list[str], length: int | None = None) -> list[str]:
    if length is None:
        seq = (w.upper() for w in words)
    else:
        seq = (w.upper() for w in words if len(w) == length)
    return sorted(set(seq))


def to_sorted_upper_unique_range(words: list[str], min_len: int, max_len: int) -> list[str]:
    seq = (w.upper() for w in words if min_len <= len(w) <= max_len)
    return sorted(set(seq))


def write_list(path: Path, title: str, words: list[str]) -> None:
    lines = [
        "# Generated from python tool/generate_wordlists.py",
        f"# {title}",
        *words,
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--answer-top-n", type=int, default=25000)
    parser.add_argument("--allowed-top-n", type=int, default=100000)
    parser.add_argument("--output-dir", type=Path, default=Path("assets/wordlists"))
    args = parser.parse_args()

    answer_freq = normalize(top_n_list("en", args.answer_top_n))
    allowed_freq = normalize(top_n_list("en", args.allowed_top_n))

    answers4 = pick_answers(answer_freq, 4)
    answers5 = pick_answers(answer_freq, 5)
    allowed4 = sorted(set(answers4) | set(to_sorted_upper_unique(allowed_freq, 4)))
    allowed5 = sorted(set(answers5) | set(to_sorted_upper_unique(allowed_freq, 5)))
    crash = to_sorted_upper_unique_range(allowed_freq, 3, 7)

    out_dir: Path = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    write_list(out_dir / "wordle_answers_4.txt", "Wordle answer pool (4 letters)", answers4)
    write_list(out_dir / "wordle_answers_5.txt", "Wordle answer pool (5 letters)", answers5)
    write_list(out_dir / "wordle_allowed_4.txt", "Wordle valid guesses (4 letters)", allowed4)
    write_list(out_dir / "wordle_allowed_5.txt", "Wordle valid guesses (5 letters)", allowed5)
    write_list(out_dir / "crash_words.txt", "Word Crash valid words (3-7 letters)", crash)

    summary = "\n".join(
        [
            "Generated word pools",
            f"- answer_top_n: {args.answer_top_n}",
            f"- allowed_top_n: {args.allowed_top_n}",
            f"- answers_4: {len(answers4)}",
            f"- answers_5: {len(answers5)}",
            f"- allowed_4: {len(allowed4)}",
            f"- allowed_5: {len(allowed5)}",
            f"- crash_3_7: {len(crash)}",
        ]
    )
    (out_dir / "summary.txt").write_text(summary + "\n", encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
