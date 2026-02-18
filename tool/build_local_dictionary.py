#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

try:
    from wordfreq import zipf_frequency
except Exception:  # pragma: no cover
    zipf_frequency = None

ALPHA = re.compile(r"^[a-z]+$")
HANGUL = re.compile(r"[\uac00-\ud7a3]")
LEGACY_PATTERN = re.compile(
    r'word:\s*"([^"]+)"\s*,\s*partOfSpeech:\s*"([^"]+)"\s*,\s*'
    r'meaning_eng:\s*"([^"]*)"\s*,\s*meaning_kor:\s*"([^"]*)"',
    re.S,
)

POS_FROM_CODE = {"n": "Noun", "v": "Verb", "a": "Adjective", "s": "Adjective", "r": "Adverb"}

NOUN_CATEGORY_MAP = {
    "food": "Food",
    "animal": "Animal",
    "plant": "Plant",
    "artifact": "Object",
    "object": "Object",
    "body": "Body",
    "person": "People",
    "location": "Place",
    "time": "Time",
    "shape": "Shape",
    "state": "State",
    "communication": "Communication",
    "act": "Action",
    "event": "Event",
    "attribute": "Attribute",
    "phenomenon": "Phenomenon",
    "substance": "Substance",
    "group": "Group",
}

VERB_CATEGORY_MAP = {
    "motion": "Movement",
    "communication": "Communication",
    "cognition": "Mind",
    "emotion": "Emotion",
    "consumption": "Consumption",
    "creation": "Creation",
    "contact": "Interaction",
    "change": "Change",
    "social": "Social",
    "body": "BodyAction",
    "possession": "Possession",
    "perception": "Perception",
    "competition": "Competition",
    "stative": "State",
    "weather": "Weather",
}

ADJ_CATEGORY_MAP = {"all": "General", "pert": "Relation", "ppl": "Participle"}
ADV_CATEGORY_MAP = {"all": "General"}

ESSENTIAL_HARD_WORDS = {
    "ECONOMY",
    "CLIMATE",
    "ENERGY",
    "HEALTH",
    "NETWORK",
    "SCIENCE",
    "MEDICINE",
    "JUSTICE",
    "DEMOCRACY",
    "CULTURE",
    "HISTORY",
    "DIGITAL",
    "SECURITY",
    "SYSTEM",
    "POLICY",
    "ANALYSIS",
    "STRATEGY",
    "RESOURCE",
    "INDUSTRY",
    "ENGINEER",
    "EDUCATION",
    "RESEARCH",
}

SPECIALIZED_KEYWORDS = {
    "taxonomy",
    "genus",
    "species",
    "phylum",
    "botany",
    "zoology",
    "mythology",
    "mythological",
    "archaic",
    "obsolete",
    "dialectal",
    "slang",
    "informal",
}

DEFINITION_PENALTY_KEYWORDS = {
    "united states",
    "genus",
    "species",
    "phylum",
    "mythology",
    "mythological",
    "vulgar",
    "offensive",
    "slang",
    "obscene",
    "coitus",
    "copulation",
    "sexual",
    "intercourse",
    "archaic",
    "obsolete",
    "dialectal",
    "abbreviation",
}


@dataclass
class DictEntry:
    word: str
    pos: str
    definition: str
    kor_definition: str
    synonyms: list[str]
    antonyms: list[str]
    theme_group: str
    theme_category: str
    frequency_zipf: float
    difficulty: int
    is_essential: bool

    def to_json(self) -> dict[str, object]:
        return {
            "word": self.word,
            "pos": self.pos,
            "definition": self.definition,
            "korDefinition": self.kor_definition,
            "synonyms": self.synonyms,
            "antonyms": self.antonyms,
            "themeGroup": self.theme_group,
            "themeCategory": self.theme_category,
            "frequencyZipf": round(self.frequency_zipf, 3),
            "difficulty": self.difficulty,
            "isEssential": self.is_essential,
        }


def normalize_word(raw: str) -> str | None:
    w = raw.strip().lower().replace("_", " ")
    if " " in w or "-" in w:
        return None
    if not ALPHA.fullmatch(w):
        return None
    return w


def category_from_filename(filename: str, pos: str) -> tuple[str, str]:
    stem = Path(filename).stem
    parts = stem.split(".")
    suffix = parts[1] if len(parts) > 1 else "all"
    if pos == "Noun":
        return ("Noun", NOUN_CATEGORY_MAP.get(suffix, "General"))
    if pos == "Verb":
        return ("Verb", VERB_CATEGORY_MAP.get(suffix, "General"))
    if pos == "Adjective":
        return ("Adjective", ADJ_CATEGORY_MAP.get(suffix, "General"))
    if pos == "Adverb":
        return ("Adverb", ADV_CATEGORY_MAP.get(suffix, "General"))
    return ("Word", "General")


def lemma_from_sense_id(sense_id: str) -> str | None:
    head = sense_id.split("%", 1)[0].strip().lower()
    return normalize_word(head)


def collect_antonyms(entries_root: Path) -> dict[tuple[str, str], set[str]]:
    out: dict[tuple[str, str], set[str]] = {}
    for p in sorted(entries_root.glob("entries-*.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        for lemma, pos_map in data.items():
            src = normalize_word(lemma)
            if src is None or not isinstance(pos_map, dict):
                continue
            for pos_code, meta in pos_map.items():
                pos = POS_FROM_CODE.get(pos_code)
                if pos is None or not isinstance(meta, dict):
                    continue
                senses = meta.get("sense", [])
                if not isinstance(senses, list):
                    continue
                for sense in senses:
                    if not isinstance(sense, dict):
                        continue
                    antonym_ids = sense.get("antonym", [])
                    if not isinstance(antonym_ids, list):
                        continue
                    key = (src, pos)
                    bucket = out.setdefault(key, set())
                    for antonym_id in antonym_ids:
                        if not isinstance(antonym_id, str):
                            continue
                        target = lemma_from_sense_id(antonym_id)
                        if target:
                            bucket.add(target)
    return out


def load_legacy_korean_map(legacy_root: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for path in sorted(legacy_root.rglob("database.js")):
        raw = path.read_text(encoding="utf-8", errors="replace")
        for word, _, eng, kor in LEGACY_PATTERN.findall(raw):
            w = normalize_word(word)
            if w is None:
                continue
            if not eng.strip() or not kor.strip():
                continue
            key = w.upper()
            current = out.get(key)
            if current is None or len(kor.strip()) > len(current):
                out[key] = kor.strip()
    return out


def estimate_zipf(word: str) -> float:
    if zipf_frequency is None:
        # Fallback heuristic if wordfreq is unavailable.
        if len(word) <= 4:
            return 5.2
        if len(word) <= 6:
            return 4.5
        if len(word) <= 8:
            return 3.8
        return 3.0
    return float(zipf_frequency(word.lower(), "en"))


def estimate_difficulty(zipf: float, length: int, essential: bool) -> int:
    if essential and zipf < 3.6:
        return 5
    if zipf >= 4.8:
        return 1
    if zipf >= 4.4:
        return 2
    if zipf >= 4.0:
        return 3
    if zipf >= 3.4:
        return 4
    if zipf >= 3.0:
        return 5
    return 6


def is_specialized(definition: str) -> bool:
    lower = definition.lower()
    return any(token in lower for token in SPECIALIZED_KEYWORDS)


def definition_quality(definition: str) -> float:
    lower = definition.lower()
    score = 100.0
    if ";" in definition:
        score -= 6
    if definition.startswith("("):
        score -= 5
    if len(definition) < 18:
        score -= 8
    elif len(definition) > 160:
        score -= 8
    elif len(definition) > 120:
        score -= 4
    for token in DEFINITION_PENALTY_KEYWORDS:
        if token in lower:
            score -= 14
    if "of or relating to or characteristic of" in lower:
        score -= 5
    if "informal term" in lower:
        score -= 10
    return score


def sanitize_korean(text: str) -> str:
    value = text.strip().replace("\r", " ").replace("\n", " ")
    value = re.sub(r"\s+", " ", value)
    if not value:
        return "Korean meaning pending"
    if "\ufffd" in value:
        return "Korean meaning pending"
    if not HANGUL.search(value):
        return "Korean meaning pending"
    if len(value) > 80:
        return "Korean meaning pending"
    return value


def has_vowel(word: str) -> bool:
    return any(ch in "aeiouy" for ch in word.lower())


def build_valid_lexicon(wordnet_root: Path, min_len: int, max_len: int) -> set[str]:
    valid: set[str] = set()
    synset_files = sorted(
        [
            p
            for p in wordnet_root.glob("*.json")
            if not p.name.startswith("entries-")
            and p.name != "frames.json"
            and "." in p.stem
            and p.stem.split(".")[0] in {"noun", "verb", "adj", "adv"}
        ]
    )
    for p in synset_files:
        data = json.loads(p.read_text(encoding="utf-8"))
        for syn in data.values():
            if not isinstance(syn, dict):
                continue
            definition_list = syn.get("definition", [])
            if not isinstance(definition_list, list) or not definition_list:
                continue
            definition = str(definition_list[0]).strip()
            if not definition:
                continue
            lower = definition.lower()
            if any(t in lower for t in {"abbreviation", "acronym", "initialism"}):
                continue
            if any(t in lower for t in {"vulgar", "offensive", "obscene", "sexual", "coitus", "copulation"}):
                continue

            members = syn.get("members", [])
            if not isinstance(members, list):
                continue
            for m in members:
                if not isinstance(m, str):
                    continue
                w = normalize_word(m)
                if w is None:
                    continue
                if len(w) < min_len or len(w) > max_len:
                    continue
                if len(w) <= 3 and not has_vowel(w):
                    continue
                zipf = estimate_zipf(w)
                if len(w) <= 3 and zipf < 4.4:
                    continue
                if len(w) == 4 and zipf < 3.6:
                    continue
                if len(w) >= 5 and zipf < 3.0:
                    continue
                valid.add(w.upper())
    return valid


def score_entry(entry: DictEntry) -> float:
    return (
        definition_quality(entry.definition)
        + 
        entry.frequency_zipf * 30
        + len(entry.synonyms) * 3
        + len(entry.antonyms) * 4
        + (10 if entry.is_essential else 0)
        - entry.difficulty * 2
    )


def merge_entry(store: dict[str, DictEntry], incoming: DictEntry) -> None:
    current = store.get(incoming.word)
    if current is None:
        store[incoming.word] = incoming
        return
    if score_entry(incoming) > score_entry(current):
        store[incoming.word] = incoming


def build_candidates(
    wordnet_root: Path,
    min_len: int,
    max_len: int,
    korean_map: dict[str, str],
) -> list[DictEntry]:
    antonyms = collect_antonyms(wordnet_root)
    store: dict[str, DictEntry] = {}

    synset_files = sorted(
        [
            p
            for p in wordnet_root.glob("*.json")
            if not p.name.startswith("entries-")
            and p.name != "frames.json"
            and "." in p.stem
            and p.stem.split(".")[0] in {"noun", "verb", "adj", "adv"}
        ]
    )

    for p in synset_files:
        data = json.loads(p.read_text(encoding="utf-8"))
        for syn in data.values():
            if not isinstance(syn, dict):
                continue
            pos_code = str(syn.get("partOfSpeech", "")).strip()
            pos = POS_FROM_CODE.get(pos_code)
            if pos is None:
                continue
            definitions = syn.get("definition", [])
            if not isinstance(definitions, list) or not definitions:
                continue
            definition = str(definitions[0]).strip()
            if not definition or len(definition) < 12:
                continue
            members = syn.get("members", [])
            if not isinstance(members, list) or not members:
                continue

            group, category = category_from_filename(p.name, pos)
            norm_members: list[str] = []
            for m in members:
                if not isinstance(m, str):
                    continue
                nm = normalize_word(m)
                if nm is None:
                    continue
                if len(nm) < min_len or len(nm) > max_len:
                    continue
                norm_members.append(nm)
            if not norm_members:
                continue

            unique_members = sorted(set(norm_members))
            for lemma in unique_members:
                key = lemma.upper()
                zipf = estimate_zipf(lemma)
                essential = key in ESSENTIAL_HARD_WORDS
                if len(lemma) <= 3 and zipf < 5.0 and not essential:
                    continue
                if len(lemma) == 4 and zipf < 4.0 and not essential:
                    continue
                if zipf < 3.1 and not essential:
                    continue
                if is_specialized(definition) and zipf < 4.2 and not essential:
                    continue
                if definition_quality(definition) < 66 and not essential:
                    continue
                difficulty = estimate_difficulty(zipf, len(lemma), essential)

                syns = [w.upper() for w in unique_members if w != lemma][:8]
                ants = sorted({w.upper() for w in antonyms.get((lemma, pos), set()) if w != lemma})[:6]
                kor = sanitize_korean(korean_map.get(key, "Korean meaning pending"))
                entry = DictEntry(
                    word=key,
                    pos=pos,
                    definition=definition,
                    kor_definition=kor,
                    synonyms=syns,
                    antonyms=ants,
                    theme_group=group,
                    theme_category=category,
                    frequency_zipf=zipf,
                    difficulty=difficulty,
                    is_essential=essential,
                )
                merge_entry(store, entry)

    return list(store.values())


def select_balanced(entries: list[DictEntry], target_size: int) -> list[DictEntry]:
    # Mostly easy-mid, smaller hard tail.
    quota = {1: 1800, 2: 2400, 3: 2800, 4: 2200, 5: 700, 6: 100}
    by_diff: dict[int, list[DictEntry]] = {k: [] for k in quota}
    for e in entries:
        by_diff.setdefault(e.difficulty, []).append(e)
    for level in by_diff:
        by_diff[level].sort(
            key=lambda e: (
                0 if e.is_essential else 1,
                -e.frequency_zipf,
                len(e.word),
                e.word,
            )
        )

    picked: list[DictEntry] = []
    used: set[str] = set()
    for level, limit in quota.items():
        for e in by_diff.get(level, []):
            if len(picked) >= target_size:
                break
            if len([x for x in picked if x.difficulty == level]) >= limit:
                break
            if e.word in used:
                continue
            picked.append(e)
            used.add(e.word)

    if len(picked) < target_size:
        leftovers = sorted(
            [e for e in entries if e.word not in used],
            key=lambda e: (0 if e.is_essential else 1, -e.frequency_zipf, e.difficulty, len(e.word), e.word),
        )
        for e in leftovers:
            if len(picked) >= target_size:
                break
            picked.append(e)
            used.add(e.word)

    picked.sort(key=lambda e: (e.difficulty, len(e.word), e.word))
    return picked[:target_size]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wordnet-root", type=Path, default=Path("data_sources/wordnet"))
    parser.add_argument("--legacy-root", type=Path, default=Path("..") / "2025")
    parser.add_argument("--output", type=Path, default=Path("assets/wordlists/local_dictionary.json"))
    parser.add_argument("--target-size", type=int, default=10000)
    parser.add_argument("--min-len", type=int, default=3)
    parser.add_argument("--max-len", type=int, default=9)
    args = parser.parse_args()

    if not args.wordnet_root.exists():
        raise SystemExit(f"WordNet folder not found: {args.wordnet_root}")

    korean_map = load_legacy_korean_map(args.legacy_root)
    candidates = build_candidates(
        wordnet_root=args.wordnet_root,
        min_len=args.min_len,
        max_len=args.max_len,
        korean_map=korean_map,
    )
    selected = select_balanced(candidates, args.target_size)
    valid_lexicon = sorted(build_valid_lexicon(args.wordnet_root, args.min_len, args.max_len))

    stats = {
        "candidates": len(candidates),
        "selected": len(selected),
        "legacyKorOverlay": len(korean_map),
        "difficulty": {str(d): len([e for e in selected if e.difficulty == d]) for d in range(1, 7)},
        "pos": {
            "Noun": len([e for e in selected if e.pos == "Noun"]),
            "Verb": len([e for e in selected if e.pos == "Verb"]),
            "Adjective": len([e for e in selected if e.pos == "Adjective"]),
            "Adverb": len([e for e in selected if e.pos == "Adverb"]),
        },
    }

    payload = {
        "version": 3,
        "generatedBy": "tool/build_local_dictionary.py",
        "targetSize": args.target_size,
        "actualSize": len(selected),
        "source": "WordNet",
        "stats": stats,
        "validWords": valid_lexicon,
        "entries": [e.to_json() for e in selected],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "\n".join(
            [
                "Local dictionary built (wave-ready difficulty)",
                f"- target_size: {args.target_size}",
                f"- actual_size: {len(selected)}",
                f"- candidates: {len(candidates)}",
                f"- difficulty: {stats['difficulty']}",
                f"- output: {args.output}",
            ]
        )
    )


if __name__ == "__main__":
    main()
