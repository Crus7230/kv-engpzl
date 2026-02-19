#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

HANGUL_RE = re.compile(r"[\uAC00-\uD7A3]")
TOKEN_RE = re.compile(r"[a-z']+")
ASCII_RE = re.compile(r"[A-Za-z]")
PENDING_KOR = "Korean meaning pending"

STOPWORDS = {
    "a",
    "an",
    "the",
    "of",
    "to",
    "in",
    "on",
    "for",
    "at",
    "from",
    "as",
    "is",
    "are",
    "be",
    "been",
    "being",
    "it",
    "its",
    "this",
    "that",
    "these",
    "those",
    "which",
    "who",
    "whom",
    "whose",
    "can",
    "will",
    "may",
    "might",
    "must",
    "would",
    "could",
    "should",
    "any",
    "all",
    "such",
    "and",
    "or",
    "with",
    "without",
    "by",
    "into",
    "through",
    "between",
    "than",
    "if",
    "then",
    "also",
    "etc",
    "one",
    "two",
    "more",
    "other",
}

MANUAL_KO = {
    "person": "사람",
    "people": "사람들",
    "someone": "누군가",
    "something": "어떤 것",
    "state": "상태",
    "quality": "특성",
    "act": "행위",
    "action": "행동",
    "activity": "활동",
    "manner": "방식",
    "process": "과정",
    "form": "형태",
    "part": "부분",
    "place": "장소",
    "time": "시간",
    "group": "집단",
    "system": "체계",
    "device": "장치",
    "law": "법",
    "government": "정부",
    "language": "언어",
    "body": "몸",
    "water": "물",
    "air": "공기",
    "light": "빛",
    "sound": "소리",
    "food": "음식",
    "color": "색",
    "animal": "동물",
    "plant": "식물",
    "human": "인간",
    "used": "사용",
    "using": "사용",
    "use": "사용",
    "made": "제작",
    "making": "제작",
    "having": "가진",
    "without": "없는",
    "relating": "관련",
    "related": "관련",
    "characterized": "특징",
    "consisting": "구성",
    "including": "포함",
    "causing": "유발",
    "large": "큰",
    "small": "작은",
    "short": "짧은",
    "long": "긴",
    "high": "높은",
    "low": "낮은",
    "good": "좋은",
    "bad": "나쁜",
    "new": "새로운",
    "old": "오래된",
    "written": "글로 된",
    "spoken": "말로 하는",
    "official": "공식",
    "public": "공공",
    "social": "사회",
    "physical": "신체",
    "mental": "정신",
    "military": "군사",
    "business": "업무",
}

IRREGULAR = {
    "been": "be",
    "was": "be",
    "were": "be",
    "am": "be",
    "is": "be",
    "are": "be",
    "did": "do",
    "done": "do",
    "does": "do",
    "had": "have",
    "has": "have",
    "went": "go",
    "gone": "go",
    "got": "get",
    "gotten": "get",
    "took": "take",
    "taken": "take",
    "saw": "see",
    "seen": "see",
    "knew": "know",
    "known": "know",
    "came": "come",
    "made": "make",
    "built": "build",
    "brought": "bring",
    "bought": "buy",
    "thought": "think",
    "wrote": "write",
    "written": "write",
    "ran": "run",
    "began": "begin",
    "begun": "begin",
    "felt": "feel",
    "found": "find",
    "left": "leave",
    "said": "say",
    "told": "tell",
    "men": "man",
    "women": "woman",
    "children": "child",
    "people": "person",
    "feet": "foot",
    "teeth": "tooth",
    "mice": "mouse",
    "geese": "goose",
    "indices": "index",
    "media": "medium",
    "data": "datum",
    "carried": "carry",
    "dropped": "drop",
    "caught": "catch",
    "grew": "grow",
    "taught": "teach",
    "shown": "show",
    "meant": "mean",
    "forgot": "forget",
}

SPECIAL_OVERRIDES = {
    "OLIVE": "덜 익은 열매와 비슷한 녹황색, 또는 기름과 식재료로 쓰이는 작은 타원형 과실.",
}


def has_valid_korean(text: str) -> bool:
    value = str(text or "").strip()
    if not value:
        return False
    if value.lower() == PENDING_KOR.lower():
        return False
    if ASCII_RE.search(value):
        return False
    return bool(HANGUL_RE.search(value))


def first_gloss(text: str) -> str | None:
    if not has_valid_korean(text):
        return None
    value = str(text).strip()
    value = re.sub(r"\([^)]*\)", " ", value)
    value = value.replace(";", ",").replace("/", ",").replace("|", ",")
    parts = [x.strip() for x in value.split(",") if x.strip()]
    if not parts:
        return None
    gloss = re.sub(r"\s+", " ", parts[0]).strip(" .")
    if not gloss:
        return None
    if len(gloss) > 24:
        gloss = " ".join(gloss.split()[:4])
    return gloss if gloss else None


def token_variants(token: str) -> list[str]:
    w = token.lower()
    out = [w]
    if w in IRREGULAR:
        out.append(IRREGULAR[w])
    if w.endswith("ies") and len(w) > 3:
        out.append(w[:-3] + "y")
    if w.endswith("ves") and len(w) > 3:
        out.append(w[:-3] + "f")
    if w.endswith("ing") and len(w) > 4:
        base = w[:-3]
        out.extend([base, base + "e"])
        if len(base) >= 2 and base[-1] == base[-2]:
            out.append(base[:-1])
    if w.endswith("ed") and len(w) > 3:
        base = w[:-2]
        out.extend([base, base + "e"])
        if len(base) >= 2 and base[-1] == base[-2]:
            out.append(base[:-1])
    if w.endswith("es") and len(w) > 3:
        out.append(w[:-2])
    if w.endswith("s") and len(w) > 2:
        out.append(w[:-1])
    if w.endswith("ly") and len(w) > 3:
        out.append(w[:-2])
    if w.endswith("er") and len(w) > 3:
        out.extend([w[:-2], w[:-2] + "e"])
    if w.endswith("est") and len(w) > 4:
        out.extend([w[:-3], w[:-3] + "e"])
    dedup: list[str] = []
    for item in out:
        if item and item not in dedup:
            dedup.append(item)
    return dedup


def lookup_keyword(token: str, lexicon: dict[str, str], target_word: str) -> str | None:
    for variant in token_variants(token):
        if variant == target_word.lower():
            continue
        if variant in MANUAL_KO:
            return MANUAL_KO[variant]
        if variant in lexicon:
            return lexicon[variant]
    return None


def generate_korean(definition: str, pos: str, word: str, lexicon: dict[str, str]) -> str:
    cleaned = re.sub(r"\([^)]*\)", " ", str(definition or "").lower())
    cleaned = cleaned.split(";")[0].split(",")[0]
    keywords: list[str] = []
    for token in TOKEN_RE.findall(cleaned):
        if token in STOPWORDS:
            continue
        ko = lookup_keyword(token, lexicon, word)
        if ko and ko not in keywords:
            keywords.append(ko)
        if len(keywords) >= 3:
            break
    core = ", ".join(keywords)
    if pos == "Noun":
        return f"{core}과 관련된 명사." if core else "사물, 개념, 상태를 가리키는 명사."
    if pos == "Verb":
        return f"{core}와 관련된 동작을 나타내는 동사." if core else "행동이나 변화를 나타내는 동사."
    if pos == "Adjective":
        return f"{core}한 성질을 나타내는 형용사." if core else "성질이나 상태를 나타내는 형용사."
    if pos == "Adverb":
        return f"{core}하게 쓰이는 부사." if core else "동작이나 상태를 꾸며 주는 부사."
    return f"{core}과 관련된 어휘." if core else "의미를 가진 영어 어휘 항목."


def normalize_pos(value: str) -> str:
    v = str(value or "").strip()
    if v in {"Noun", "Verb", "Adjective", "Adverb"}:
        return v
    return "Word"


def build_lexicon(entries: list[dict[str, object]]) -> dict[str, str]:
    lex: dict[str, str] = {}
    for item in entries:
        word = str(item.get("word", "")).strip().lower()
        if not word.isalpha():
            continue
        gloss = first_gloss(str(item.get("korDefinition", "")))
        if gloss:
            lex.setdefault(word, gloss)
    return lex


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("assets/wordlists/local_dictionary.json"))
    parser.add_argument("--limit", type=int, default=0, help="0 means all target entries")
    args = parser.parse_args()

    payload = json.loads(args.input.read_text(encoding="utf-8"))
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise SystemExit("Invalid local_dictionary.json: entries is not a list")

    lexicon = build_lexicon([e for e in entries if isinstance(e, dict)])

    updated = 0
    processed = 0
    for row in entries:
        if not isinstance(row, dict):
            continue
        word = str(row.get("word", "")).strip().upper()
        if not word:
            continue

        current = str(row.get("korDefinition", "")).strip()
        need = current == PENDING_KOR or word in SPECIAL_OVERRIDES
        if not need:
            continue

        if word in SPECIAL_OVERRIDES:
            row["korDefinition"] = SPECIAL_OVERRIDES[word]
            updated += 1
            processed += 1
        else:
            definition = str(row.get("definition", "")).strip()
            pos = normalize_pos(str(row.get("pos", "Word")))
            new_kor = generate_korean(definition, pos, word, lexicon)
            if has_valid_korean(new_kor):
                row["korDefinition"] = new_kor
                updated += 1
            processed += 1

        if args.limit > 0 and processed >= args.limit:
            break

    payload["generatedBy"] = "tool/fill_local_kor_offline.py"
    args.input.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    pending_left = sum(
        1 for e in entries if isinstance(e, dict) and str(e.get("korDefinition", "")).strip() == PENDING_KOR
    )
    print("Filled local Korean meanings (offline)")
    print(f"- updated: {updated}")
    print(f"- processed: {processed}")
    print(f"- pending_left: {pending_left}")
    print(f"- output: {args.input}")


if __name__ == "__main__":
    main()

