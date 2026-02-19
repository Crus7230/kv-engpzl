#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import urllib.error
import urllib.request
from pathlib import Path

PLACEHOLDER_ENG = "A commonly used English word with"
PLACEHOLDER_KOR_1 = "\uC790\uC8FC \uC4F0\uB294"  # 자주 쓰는
PLACEHOLDER_KOR_2 = "\uC601\uC5B4 \uB2E8\uC5B4"  # 영어 단어
PENDING_KOR = "Korean meaning pending"

TOKEN_RE = re.compile(r"[a-z']+")
HANGUL_RE = re.compile(r"[\uAC00-\uD7A3]")
ALPHA_RE = re.compile(r"^[A-Z]+$")
ASCII_RE = re.compile(r"[A-Za-z]")

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

MANUAL_KO_KEYWORDS = {
    "person": "\uC0AC\uB78C",
    "people": "\uC0AC\uB78C\uB4E4",
    "someone": "\uB204\uAD70\uAC00",
    "something": "\uC5B4\uB5A4 \uAC83",
    "state": "\uC0C1\uD0DC",
    "quality": "\uD2B9\uC131",
    "act": "\uD589\uC704",
    "action": "\uD589\uB3D9",
    "activity": "\uD65C\uB3D9",
    "manner": "\uBC29\uC2DD",
    "process": "\uACFC\uC815",
    "form": "\uD615\uD0DC",
    "part": "\uBD80\uBD84",
    "place": "\uC7A5\uC18C",
    "time": "\uC2DC\uAC04",
    "group": "\uC9D1\uB2E8",
    "system": "\uCCB4\uACC4",
    "device": "\uC7A5\uCE58",
    "law": "\uBC95",
    "government": "\uC815\uBD80",
    "language": "\uC5B8\uC5B4",
    "body": "\uBAB8",
    "water": "\uBB3C",
    "air": "\uACF5\uAE30",
    "light": "\uBE5B",
    "sound": "\uC18C\uB9AC",
    "food": "\uC74C\uC2DD",
    "color": "\uC0C9",
    "animal": "\uB3D9\uBB3C",
    "plant": "\uC2DD\uBB3C",
    "human": "\uC778\uAC04",
    "used": "\uC0AC\uC6A9",
    "using": "\uC0AC\uC6A9",
    "use": "\uC0AC\uC6A9",
    "made": "\uC81C\uC791",
    "making": "\uC81C\uC791",
    "having": "\uAC00\uC9C4",
    "without": "\uC5C6\uB294",
    "relating": "\uAD00\uB828",
    "related": "\uAD00\uB828",
    "characterized": "\uD2B9\uC9D5",
    "consisting": "\uAD6C\uC131",
    "including": "\uD3EC\uD568",
    "causing": "\uC720\uBC1C",
    "large": "\uD070",
    "small": "\uC791\uC740",
    "short": "\uC9E7\uC740",
    "long": "\uAE34",
    "high": "\uB192\uC740",
    "low": "\uB0AE\uC740",
    "good": "\uC88B\uC740",
    "bad": "\uB098\uC05C",
    "new": "\uC0C8\uB85C\uC6B4",
    "old": "\uC624\uB798\uB41C",
    "written": "\uAE00\uB85C \uB41C",
    "spoken": "\uB9D0\uB85C \uD558\uB294",
    "official": "\uACF5\uC2DD",
    "public": "\uACF5\uACF5",
    "social": "\uC0AC\uD68C",
    "physical": "\uC2E0\uCCB4",
    "mental": "\uC815\uC2E0",
    "military": "\uAD70\uC0AC",
    "business": "\uC5C5\uBB34",
}

MANUAL_DEFINITIONS = {
    "THAN": (
        "Conjunction",
        "used to introduce the second element in a comparison",
        "\uBE44\uAD50\uD560 \uB54C \uB4B7\uBD80\uBD84\uC744 \uC787\uB294 \uC811\uC18D\uC0AC.",
    ),
    "SINCE": (
        "Preposition",
        "from a particular time in the past until now",
        "\uACFC\uAC70 \uD2B9\uC815 \uC2DC\uC810\uBD80\uD130 \uC9C0\uAE08\uAE4C\uC9C0\uB97C \uB098\uD0C0\uB0B4\uB294 \uB9D0.",
    ),
    "DURING": (
        "Preposition",
        "throughout the course or duration of a period",
        "\uC5B4\uB5A4 \uAE30\uAC04 \uB3D9\uC548\uC744 \uB098\uD0C0\uB0B4\uB294 \uC804\uCE58\uC0AC.",
    ),
    "WITHOUT": (
        "Preposition",
        "in the absence of; not having",
        "\uC5C6\uC774, \uAC00\uC9C0\uC9C0 \uC54A\uACE0 \uB77C\uB294 \uB73B\uC758 \uC804\uCE58\uC0AC.",
    ),
    "WHETHER": (
        "Conjunction",
        "used to introduce alternatives or possibilities",
        "\uC5EC\uB7EC \uAC00\uB2A5\uC131\uC774\uB098 \uC120\uD0DD\uC9C0\uB97C \uC774\uC744 \uB54C \uC4F0\uB294 \uC811\uC18D\uC0AC.",
    ),
    "WHOM": (
        "Pronoun",
        "used instead of who as the object of a verb or preposition",
        "\uB3D9\uC0AC\uB098 \uC804\uCE58\uC0AC\uC758 \uBAA9\uC801\uC5B4 \uC790\uB9AC\uC5D0 \uC4F0\uB294 \uAD00\uACC4\uB300\uBA85\uC0AC \uD615\uD0DC.",
    ),
    "WHOSE": (
        "Pronoun",
        "used to ask or say who something belongs to",
        "\uC18C\uC720 \uAD00\uACC4\uB97C \uBB3B\uAC70\uB098 \uB098\uD0C0\uB0BC \uB54C \uC4F0\uB294 \uB300\uBA85\uC0AC.",
    ),
    "CANNOT": (
        "Verb",
        "cannot; not able to",
        "\uD560 \uC218 \uC5C6\uB2E4\uB294 \uB73B\uC744 \uB098\uD0C0\uB0B4\uB294 \uD45C\uD604.",
    ),
    "DONT": (
        "Verb",
        "informal contraction of do not",
        "\uBD80\uC815 \uC758\uBBF8\uB97C \uBE44\uACF5\uC2DD\uC801\uC73C\uB85C \uC904\uC5EC \uB9D0\uD558\uB294 \uD45C\uD604.",
    ),
    "GONNA": (
        "Word",
        "informal spoken form of going to",
        "\uAC00\uAE4C\uC6B4 \uBBF8\uB798 \uACC4\uD68D\uC774\uB098 \uC758\uB3C4\uB97C \uAD6C\uC5B4\uCCB4\uB85C \uC904\uC5EC \uB9D0\uD558\uB294 \uD45C\uD604.",
    ),
    "WANNA": (
        "Word",
        "informal spoken form of want to",
        "\uC6D0\uD568\uC774\uB098 \uC758\uC9C0\uB97C \uAD6C\uC5B4\uCCB4\uB85C \uC904\uC5EC \uB9D0\uD558\uB294 \uD45C\uD604.",
    ),
    "GOTTA": (
        "Word",
        "informal spoken form of got to or have to",
        "\uC758\uBB34\uB098 \uD544\uC694\uB97C \uAD6C\uC5B4\uCCB4\uB85C \uAC15\uC870\uD558\uC5EC \uB9D0\uD558\uB294 \uD45C\uD604.",
    ),
}

FORCE_LOCAL_KOR_WORDS = {"OLIVE"}

IRREGULAR_LEMMA = {
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

POS_FROM_CODE = {"n": "Noun", "v": "Verb", "a": "Adjective", "s": "Adjective", "r": "Adverb"}
SYNSET_FILES = {
    "n": "noun.*.json",
    "v": "verb.*.json",
    "a": "adj.*.json",
    "s": "adj.*.json",
    "r": "adv.*.json",
}


def is_placeholder_meaning(text: str) -> bool:
    return PLACEHOLDER_ENG.lower() in str(text or "").lower()


def is_bad_kor(text: str) -> bool:
    s = str(text or "")
    return PLACEHOLDER_KOR_1 in s or PLACEHOLDER_KOR_2 in s or "\uFFFD" in s


def has_valid_korean(text: str) -> bool:
    s = str(text or "").strip()
    if not s:
        return False
    if PENDING_KOR.lower() in s.lower():
        return False
    if is_bad_kor(s):
        return False
    if ASCII_RE.search(s):
        return False
    return bool(HANGUL_RE.search(s))


def first_korean_gloss(text: str) -> str | None:
    if not has_valid_korean(text):
        return None
    s = str(text).strip()
    s = re.sub(r"\([^)]*\)", " ", s)
    s = s.replace(";", ",").replace("/", ",").replace("|", ",")
    parts = [x.strip() for x in s.split(",") if x.strip()]
    if not parts:
        return None
    gloss = re.sub(r"\s+", " ", parts[0]).strip(" .")
    if not gloss:
        return None
    if len(gloss) > 24:
        gloss = " ".join(gloss.split()[:4])
    return gloss if gloss else None


class WordNetLookup:
    def __init__(self, root: Path) -> None:
        self.root = root
        self._entries_cache: dict[str, dict[str, object]] = {}
        self._synset_cache: dict[str, dict[str, str]] = {}

    def _entries_for_letter(self, letter: str) -> dict[str, object]:
        key = letter if letter.isalpha() else "0"
        if key in self._entries_cache:
            return self._entries_cache[key]
        path = self.root / f"entries-{key}.json"
        if not path.exists():
            self._entries_cache[key] = {}
            return self._entries_cache[key]
        self._entries_cache[key] = json.loads(path.read_text(encoding="utf-8"))
        return self._entries_cache[key]

    def _synset_definition(self, pos_code: str, synset_id: str) -> str | None:
        if pos_code not in self._synset_cache:
            bucket: dict[str, str] = {}
            pattern = SYNSET_FILES.get(pos_code)
            if pattern is None:
                self._synset_cache[pos_code] = bucket
                return None
            for path in sorted(self.root.glob(pattern)):
                data = json.loads(path.read_text(encoding="utf-8"))
                for sid, meta in data.items():
                    if not isinstance(meta, dict):
                        continue
                    definitions = meta.get("definition")
                    if not isinstance(definitions, list) or not definitions:
                        continue
                    definition = str(definitions[0]).strip()
                    if definition and sid not in bucket:
                        bucket[sid] = definition
            self._synset_cache[pos_code] = bucket
        return self._synset_cache[pos_code].get(synset_id)

    @staticmethod
    def _lemma_variants(word: str) -> list[str]:
        w = word.lower()
        out = [w]
        if w in IRREGULAR_LEMMA:
            out.append(IRREGULAR_LEMMA[w])
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
            base = w[:-2]
            out.extend([base, base + "e"])
            if len(base) >= 2 and base[-1] == base[-2]:
                out.append(base[:-1])
        if w.endswith("est") and len(w) > 4:
            base = w[:-3]
            out.extend([base, base + "e"])
            if len(base) >= 2 and base[-1] == base[-2]:
                out.append(base[:-1])
        dedup: list[str] = []
        for item in out:
            if item and item not in dedup:
                dedup.append(item)
        return dedup

    def lookup(self, word: str) -> tuple[str, str] | None:
        for lemma in self._lemma_variants(word):
            if not lemma or not lemma[0].isalpha():
                continue
            entries = self._entries_for_letter(lemma[0])
            meta = entries.get(lemma)
            if not isinstance(meta, dict):
                continue
            for pos_code in ("n", "v", "a", "s", "r"):
                pos_meta = meta.get(pos_code)
                if not isinstance(pos_meta, dict):
                    continue
                senses = pos_meta.get("sense")
                if not isinstance(senses, list):
                    continue
                for sense in senses:
                    if not isinstance(sense, dict):
                        continue
                    synset_id = sense.get("synset")
                    if not isinstance(synset_id, str):
                        continue
                    definition = self._synset_definition(pos_code, synset_id)
                    if definition:
                        return POS_FROM_CODE[pos_code], definition
        return None


def build_lexicon(local_entries: list[dict[str, object]], clue_entries: list[dict[str, object]]) -> dict[str, str]:
    lex: dict[str, str] = {}
    for item in local_entries:
        word = str(item.get("word", "")).strip().lower()
        if not word.isalpha():
            continue
        gloss = first_korean_gloss(str(item.get("korDefinition", "")))
        if gloss:
            lex.setdefault(word, gloss)
    for item in clue_entries:
        word = str(item.get("word", "")).strip().lower()
        if not word.isalpha():
            continue
        if is_placeholder_meaning(str(item.get("meaning", ""))):
            continue
        gloss = first_korean_gloss(str(item.get("korMeaning", "")))
        if gloss:
            lex.setdefault(word, gloss)
    return lex


def token_variants(token: str) -> list[str]:
    w = token.lower()
    out = [w]
    if w in IRREGULAR_LEMMA:
        out.append(IRREGULAR_LEMMA[w])
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


def lookup_korean_keyword(token: str, lexicon: dict[str, str]) -> str | None:
    for variant in token_variants(token):
        if variant in MANUAL_KO_KEYWORDS:
            return MANUAL_KO_KEYWORDS[variant]
        if variant in lexicon:
            return lexicon[variant]
    return None


def generate_korean_meaning(
    definition: str,
    pos: str,
    word: str,
    lexicon: dict[str, str],
    translator: TranslatorClient | None = None,
) -> str:
    if translator is not None:
        translated = translator.translate(definition)
        if translated:
            return translated
    cleaned = re.sub(r"\([^)]*\)", " ", str(definition or "").lower())
    cleaned = cleaned.split(";")[0].split(",")[0]
    keywords: list[str] = []
    for token in TOKEN_RE.findall(cleaned):
        if token in STOPWORDS:
            continue
        ko = lookup_korean_keyword(token, lexicon)
        if ko and ko not in keywords:
            keywords.append(ko)
        if len(keywords) >= 3:
            break
    core = ", ".join(keywords)
    if pos == "Noun":
        return f"{core}\uACFC \uAD00\uB828\uB41C \uBA85\uC0AC." if core else "\uC0AC\uBB3C, \uAC1C\uB150, \uC0C1\uD0DC\uB97C \uAC00\uB9AC\uD0A4\uB294 \uBA85\uC0AC."
    if pos == "Verb":
        return (
            f"{core}\uC640 \uAD00\uB828\uB41C \uB3D9\uC791\uC744 \uB73B\uD558\uB294 \uB3D9\uC0AC."
            if core
            else "\uD589\uB3D9\uC774\uB098 \uBCC0\uD654\uB97C \uB098\uD0C0\uB0B4\uB294 \uB3D9\uC0AC."
        )
    if pos == "Adjective":
        return (
            f"{core}\uD55C \uC131\uC9C8\uC744 \uB098\uD0C0\uB0B4\uB294 \uD615\uC6A9\uC0AC."
            if core
            else "\uC131\uC9C8\uC774\uB098 \uC0C1\uD0DC\uB97C \uB098\uD0C0\uB0B4\uB294 \uD615\uC6A9\uC0AC."
        )
    if pos == "Adverb":
        return (
            f"{core}\uD558\uAC8C \uC4F0\uC774\uB294 \uBD80\uC0AC."
            if core
            else "\uB3D9\uC791\uC774\uB098 \uC0C1\uD0DC\uB97C \uAFB8\uBA70 \uC8FC\uB294 \uBD80\uC0AC."
        )
    return f"{core}\uACFC \uAD00\uB828\uB41C \uB2E8\uC5B4." if core else "\uC758\uBBF8\uB97C \uAC00\uC9C4 \uC601\uC5B4 \uC5B4\uD718 \uD56D\uBAA9."


class TranslatorClient:
    def __init__(self, url: str | None, timeout_seconds: float = 8.0) -> None:
        self.url = url.strip() if isinstance(url, str) else None
        self.timeout_seconds = timeout_seconds
        self._cache: dict[str, str | None] = {}

    def translate(self, text: str) -> str | None:
        if not self.url:
            return None
        query = str(text or "").strip()
        if not query:
            return None
        if query in self._cache:
            return self._cache[query]
        payload = json.dumps(
            {
                "q": query,
                "source": "en",
                "target": "ko",
                "format": "text",
            }
        ).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                raw = response.read().decode("utf-8", errors="replace")
                data = json.loads(raw)
                translated = str(data.get("translatedText", "")).strip()
                if translated and has_valid_korean(translated):
                    self._cache[query] = translated
                    return translated
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
            pass
        self._cache[query] = None
        return None


def fallback_definition(word: str, pos: str) -> tuple[str, str]:
    upper = word.upper()
    if upper in MANUAL_DEFINITIONS:
        manual_pos, manual_meaning, _ = MANUAL_DEFINITIONS[upper]
        return manual_pos, manual_meaning
    if pos == "Verb":
        return "Verb", f"to perform an action related to {word.lower()}"
    if pos == "Adjective":
        return "Adjective", f"describing a quality related to {word.lower()}"
    if pos == "Adverb":
        return "Adverb", f"in a manner related to {word.lower()}"
    if pos == "Noun":
        return "Noun", f"a noun related to {word.lower()}"
    if ALPHA_RE.fullmatch(upper):
        return "Word", "a proper noun used as a name for a person, place, or organization"
    return "Word", f"a common English word represented by {word.lower()}"


def manual_korean_for_word(word: str) -> str | None:
    item = MANUAL_DEFINITIONS.get(word.upper())
    if item is None:
        return None
    return item[2]


def normalize_pos(value: str) -> str:
    v = str(value or "").strip()
    if v in {"Noun", "Verb", "Adjective", "Adverb", "Word", "Pronoun", "Conjunction", "Preposition"}:
        return v
    return "Word"


def repair(
    clue_path: Path,
    local_dict_path: Path,
    anagram_path: Path | None,
    wordnet_root: Path,
    translate_url: str | None = None,
) -> dict[str, int]:
    clue_obj = json.loads(clue_path.read_text(encoding="utf-8"))
    clue_entries = clue_obj.get("entries")
    if not isinstance(clue_entries, list):
        raise SystemExit("Invalid clue_words.json: entries is not a list")

    local_obj = json.loads(local_dict_path.read_text(encoding="utf-8"))
    local_entries = local_obj.get("entries")
    if not isinstance(local_entries, list):
        raise SystemExit("Invalid local_dictionary.json: entries is not a list")

    local_by_word: dict[str, dict[str, object]] = {}
    for row in local_entries:
        if not isinstance(row, dict):
            continue
        word = str(row.get("word", "")).upper()
        if word:
            local_by_word[word] = row

    wordnet = WordNetLookup(wordnet_root)
    lexicon = build_lexicon(local_entries, clue_entries)
    translator = TranslatorClient(translate_url)

    changed_meaning = 0
    changed_kor = 0
    changed_pos = 0

    for item in clue_entries:
        if not isinstance(item, dict):
            continue
        word = str(item.get("word", "")).upper().strip()
        if not word:
            continue

        original_meaning = str(item.get("meaning", "")).strip()
        original_kor = str(item.get("korMeaning", "")).strip()
        original_pos = normalize_pos(str(item.get("pos", "Word")))

        new_pos = original_pos
        new_meaning = original_meaning

        if is_placeholder_meaning(original_meaning):
            local = local_by_word.get(word)
            if local is not None:
                local_meaning = str(local.get("definition", "")).strip()
                local_pos = normalize_pos(str(local.get("pos", "Word")))
                if local_meaning and not is_placeholder_meaning(local_meaning):
                    new_meaning = local_meaning
                    new_pos = local_pos
                else:
                    found = wordnet.lookup(word.lower())
                    if found is not None:
                        new_pos, new_meaning = found
                    else:
                        new_pos, new_meaning = fallback_definition(word, local_pos)
            else:
                found = wordnet.lookup(word.lower())
                if found is not None:
                    new_pos, new_meaning = found
                else:
                    new_pos, new_meaning = fallback_definition(word, original_pos)

        if new_meaning != original_meaning:
            item["meaning"] = new_meaning
            changed_meaning += 1
        if new_pos != original_pos:
            item["pos"] = new_pos
            changed_pos += 1

        replace_kor = (
            is_bad_kor(original_kor)
            or PENDING_KOR.lower() in original_kor.lower()
            or not has_valid_korean(original_kor)
            or word in FORCE_LOCAL_KOR_WORDS
        )
        if replace_kor:
            local = local_by_word.get(word)
            if local is not None:
                local_kor = str(local.get("korDefinition", "")).strip()
            else:
                local_kor = ""
            if has_valid_korean(local_kor):
                new_kor = local_kor
            else:
                manual_kor = manual_korean_for_word(word)
                if manual_kor:
                    new_kor = manual_kor
                else:
                    new_kor = generate_korean_meaning(
                        str(item.get("meaning", "")),
                        normalize_pos(str(item.get("pos", "Word"))),
                        word,
                        lexicon,
                        translator=translator,
                    )
            if new_kor != original_kor:
                item["korMeaning"] = new_kor
                changed_kor += 1

    clue_obj["generatedBy"] = "tool/repair_clue_placeholders.py"
    clue_path.write_text(json.dumps(clue_obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if anagram_path is not None and anagram_path.exists():
        anagram_obj = json.loads(anagram_path.read_text(encoding="utf-8"))
        rounds = anagram_obj.get("entries")
        if isinstance(rounds, list):
            clue_by_word = {str(e.get("word", "")).upper(): e for e in clue_entries if isinstance(e, dict)}
            rounds_changed = 0
            for row in rounds:
                if not isinstance(row, dict):
                    continue
                seed = str(row.get("seed", "")).upper()
                source = clue_by_word.get(seed)
                if source is None:
                    continue
                old_meaning = str(row.get("meaning", ""))
                old_kor = str(row.get("korMeaning", ""))
                old_pos = str(row.get("pos", ""))
                new_meaning = str(source.get("meaning", ""))
                new_kor = str(source.get("korMeaning", ""))
                new_pos = str(source.get("pos", "Word"))
                if old_meaning != new_meaning:
                    row["meaning"] = new_meaning
                    rounds_changed += 1
                if old_kor != new_kor:
                    row["korMeaning"] = new_kor
                    rounds_changed += 1
                if old_pos != new_pos:
                    row["pos"] = new_pos
                    rounds_changed += 1
            anagram_obj["generatedBy"] = "tool/repair_clue_placeholders.py"
            anagram_path.write_text(json.dumps(anagram_obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        else:
            rounds_changed = 0
    else:
        rounds_changed = 0

    # Post stats
    clue_meaning_placeholder = sum(
        1 for e in clue_entries if isinstance(e, dict) and is_placeholder_meaning(str(e.get("meaning", "")))
    )
    clue_kor_placeholder = sum(
        1
        for e in clue_entries
        if isinstance(e, dict) and (is_bad_kor(str(e.get("korMeaning", "")) or "") or PENDING_KOR.lower() in str(e.get("korMeaning", "")).lower())
    )

    return {
        "clue_entries": len(clue_entries),
        "changed_meaning": changed_meaning,
        "changed_kor": changed_kor,
        "changed_pos": changed_pos,
        "round_fields_changed": rounds_changed,
        "clue_meaning_placeholder_left": clue_meaning_placeholder,
        "clue_kor_placeholder_left": clue_kor_placeholder,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clue", type=Path, default=Path("assets/wordlists/clue_words.json"))
    parser.add_argument("--local", type=Path, default=Path("assets/wordlists/local_dictionary.json"))
    parser.add_argument("--anagram", type=Path, default=Path("assets/wordlists/anagram_rounds.json"))
    parser.add_argument("--wordnet-root", type=Path, default=Path("data_sources/wordnet"))
    parser.add_argument(
        "--translate-url",
        type=str,
        default="",
        help="Optional LibreTranslate-compatible endpoint URL. Example: http://127.0.0.1:5000/translate",
    )
    args = parser.parse_args()

    stats = repair(
        clue_path=args.clue,
        local_dict_path=args.local,
        anagram_path=args.anagram,
        wordnet_root=args.wordnet_root,
        translate_url=args.translate_url or None,
    )
    print("Repaired clue/anagram placeholders")
    for key, value in stats.items():
        print(f"- {key}: {value}")


if __name__ == "__main__":
    main()
