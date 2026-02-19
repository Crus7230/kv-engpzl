#!/usr/bin/env python
"""
Generate large shared assets for Word Clue + Anagram.

Outputs:
  - assets/wordlists/clue_words.json
  - assets/wordlists/anagram_rounds.json
  - assets/wordlists/clue_summary.txt

Data sources:
  - Legacy DB files in ../2025/**/database.js (real meanings when available)
  - wordfreq top_n_list (for large, frequency-based expansion)
  - Existing game wordlists for anagram dictionary bounds
"""

from __future__ import annotations

import argparse
import json
import random
import re
from collections import defaultdict
from pathlib import Path

try:
    from wordfreq import top_n_list
except Exception as exc:  # pragma: no cover
    raise SystemExit(
        "Missing dependency: wordfreq. Install with `pip install wordfreq`.\n"
        f"Import error: {exc}"
    )

ALPHA = re.compile(r"^[a-z]+$")
LEGACY_PATTERN = re.compile(
    r'word:\s*"([^"]+)"\s*,\s*partOfSpeech:\s*"([^"]+)"\s*,\s*'
    r'meaning_eng:\s*"([^"]*)"\s*,\s*meaning_kor:\s*"([^"]*)"',
    re.S,
)

# Keep in sync with tool/generate_wordlists.py.
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

POS_MAP = {
    "noun": "Noun",
    "verb": "Verb",
    "adjective": "Adjective",
    "adverb": "Adverb",
}


def normalize_word(raw: str) -> str | None:
    w = raw.strip().lower()
    if not ALPHA.fullmatch(w):
        return None
    if w in BLACKLIST:
        return None
    return w


def normalize_pos(raw: str) -> str:
    val = raw.strip().lower()
    return POS_MAP.get(val, "Word")


def guess_pos(word: str) -> str:
    if word.endswith("ly"):
        return "Adverb"
    if word.endswith(("ing", "ed", "ify", "ise", "ize")):
        return "Verb"
    if word.endswith(("ous", "ful", "less", "able", "ible", "al", "ic", "ive")):
        return "Adjective"
    if word.endswith(("tion", "sion", "ment", "ness", "ity", "ship", "age", "ism", "ist")):
        return "Noun"
    return "Word"


def load_wordlist(path: Path, min_len: int, max_len: int) -> list[str]:
    if not path.exists():
        return []
    out: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        word = line.strip().lower()
        if not word or word.startswith("#"):
            continue
        if not ALPHA.fullmatch(word):
            continue
        if len(word) < min_len or len(word) > max_len:
            continue
        out.append(word)
    return out


def parse_legacy_entries(legacy_root: Path) -> dict[str, dict[str, str]]:
    best: dict[str, dict[str, str]] = {}
    for path in sorted(legacy_root.rglob("database.js")):
        raw = path.read_text(encoding="utf-8", errors="replace")
        for word, pos, eng, kor in LEGACY_PATTERN.findall(raw):
            w = normalize_word(word)
            if w is None:
                continue
            if len(w) < 4 or len(w) > 8:
                continue
            eng = eng.strip()
            kor = kor.strip()
            if not eng or not kor:
                continue

            candidate = {
                "word": w.upper(),
                "meaning": eng,
                "korMeaning": kor,
                "pos": normalize_pos(pos),
                "synonym": "",
                "antonym": "",
            }
            current = best.get(w)
            if current is None:
                best[w] = candidate
                continue
            # Keep the richer explanation if duplicates collide.
            old_score = len(current["meaning"]) + len(current["korMeaning"])
            new_score = len(candidate["meaning"]) + len(candidate["korMeaning"])
            if new_score > old_score:
                best[w] = candidate
    return best


def build_synthetic_entry(word: str) -> dict[str, str]:
    return {
        "word": word.upper(),
        "meaning": f"A common English word used in daily communication: {word.upper()}.",
        "korMeaning": f"일상 영어에서 쓰이는 단어: {word.upper()}.",
        "pos": guess_pos(word),
        "synonym": "",
        "antonym": "",
    }


def word_signature_upper(word_upper: str) -> str:
    return "".join(sorted(word_upper))


def word_count_and_mask(word_upper: str) -> tuple[tuple[int, ...], int]:
    counts = [0] * 26
    mask = 0
    for ch in word_upper:
        idx = ord(ch) - 65
        counts[idx] += 1
        mask |= 1 << idx
    return tuple(counts), mask


def can_build(candidate_counts: tuple[int, ...], seed_counts: tuple[int, ...]) -> bool:
    for i in range(26):
        if candidate_counts[i] > seed_counts[i]:
            return False
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-clue-size", type=int, default=8000)
    parser.add_argument("--target-anagram-rounds", type=int, default=4200)
    parser.add_argument("--freq-top-n", type=int, default=140000)
    parser.add_argument("--seed", type=int, default=77)
    parser.add_argument("--output-dir", type=Path, default=Path("assets/wordlists"))
    parser.add_argument("--legacy-root", type=Path, default=Path("..") / "2025")
    args = parser.parse_args()

    random.seed(args.seed)

    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    # Frequency-ordered words (common -> less common).
    freq_words = [normalize_word(w) for w in top_n_list("en", args.freq_top_n)]
    freq_words = [w for w in freq_words if w is not None and 4 <= len(w) <= 8]

    # Legacy entries with real meanings.
    legacy = parse_legacy_entries(args.legacy_root)

    # Build a rank map to prioritize common words first.
    rank: dict[str, int] = {}
    for i, w in enumerate(freq_words):
        if w not in rank:
            rank[w] = i

    clue_entries: list[dict[str, str]] = []
    seen: set[str] = set()
    real_count = 0
    synthetic_count = 0

    # Add all legacy words first, ranked by frequency when possible.
    legacy_words_sorted = sorted(
        legacy.keys(),
        key=lambda w: (rank.get(w, 10**9), w),
    )
    for w in legacy_words_sorted:
        entry = legacy[w]
        clue_entries.append(entry)
        seen.add(w)
        real_count += 1
        if len(clue_entries) >= args.target_clue_size:
            break

    # Expand with frequency words + synthetic hints until target size.
    for w in freq_words:
        if len(clue_entries) >= args.target_clue_size:
            break
        if w in seen:
            continue
        seen.add(w)
        clue_entries.append(build_synthetic_entry(w))
        synthetic_count += 1

    # Fallback if target size is still not met (rare).
    if len(clue_entries) < args.target_clue_size:
        pool = sorted({w for w in freq_words if w not in seen})
        for w in pool:
            clue_entries.append(build_synthetic_entry(w))
            if len(clue_entries) >= args.target_clue_size:
                break

    # Build anagram dictionary from existing game wordlists.
    crash = load_wordlist(out_dir / "crash_words.txt", 3, 7)
    allowed4 = load_wordlist(out_dir / "wordle_allowed_4.txt", 4, 4)
    allowed5 = load_wordlist(out_dir / "wordle_allowed_5.txt", 5, 5)
    freq_anagram = [w for w in freq_words if 3 <= len(w) <= 7]
    anagram_dict = sorted(set(crash) | set(allowed4) | set(allowed5) | set(freq_anagram))

    by_len: dict[int, list[tuple[str, tuple[int, ...], int]]] = defaultdict(list)
    exact: dict[str, list[str]] = defaultdict(list)
    for w in anagram_dict:
        wu = w.upper()
        counts, mask = word_count_and_mask(wu)
        by_len[len(wu)].append((wu, counts, mask))
        exact[word_signature_upper(wu)].append(wu)

    seed_entries = [e for e in clue_entries if 5 <= len(e["word"]) <= 7]
    random.shuffle(seed_entries)

    rounds: list[dict[str, object]] = []
    used_seed: set[str] = set()
    for entry in seed_entries:
        if len(rounds) >= args.target_anagram_rounds:
            break
        seed = str(entry["word"]).upper()
        if seed in used_seed:
            continue
        used_seed.add(seed)

        seed_counts, seed_mask = word_count_and_mask(seed)
        core = sorted(set(exact.get(word_signature_upper(seed), [])) | {seed})

        # Scan candidates until we have enough good options.
        general: list[str] = []
        cap_for_scan = 52
        for length in range(3, len(seed)):
            for candidate, c_counts, c_mask in by_len[length]:
                if candidate == seed:
                    continue
                if c_mask & ~seed_mask:
                    continue
                if can_build(c_counts, seed_counts):
                    general.append(candidate)
                    if len(general) >= cap_for_scan:
                        break
            if len(general) >= cap_for_scan:
                break

        if not general:
            continue
        general = sorted(set(general), key=lambda w: (len(w), w))
        general = general[:24]
        if len(general) < 6:
            continue

        rounds.append(
            {
                "seed": seed,
                "meaning": entry["meaning"],
                "korMeaning": entry["korMeaning"],
                "pos": entry["pos"],
                "coreWords": core,
                "generalWords": general,
            }
        )

    clue_payload = {
        "version": 2,
        "generatedBy": "tool/generate_clue_assets.py",
        "targetSize": args.target_clue_size,
        "entries": clue_entries,
    }
    (out_dir / "clue_words.json").write_text(
        json.dumps(clue_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    round_payload = {
        "version": 1,
        "generatedBy": "tool/generate_clue_assets.py",
        "targetSize": args.target_anagram_rounds,
        "entries": rounds,
    }
    (out_dir / "anagram_rounds.json").write_text(
        json.dumps(round_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    summary = "\n".join(
        [
            "Generated clue/anagram assets",
            f"- target_clue_size: {args.target_clue_size}",
            f"- actual_clue_size: {len(clue_entries)}",
            f"- clue_real_entries: {real_count}",
            f"- clue_synthetic_entries: {synthetic_count}",
            f"- target_anagram_rounds: {args.target_anagram_rounds}",
            f"- actual_anagram_rounds: {len(rounds)}",
            f"- anagram_dictionary_size: {len(anagram_dict)}",
        ]
    )
    (out_dir / "clue_summary.txt").write_text(summary + "\n", encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()

