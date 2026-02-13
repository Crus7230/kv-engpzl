# Wordlist Assets

This folder is the single source for game dictionaries.

## Shared clue asset

`clue_words.json` is shared by:
- Word Clue (direct round source)
- Anagram (seed words + metadata display)

`anagram_rounds.json` contains prebuilt random round pools
generated from shared clue words + game dictionaries.

Schema:

```json
{
  "version": 1,
  "entries": [
    {
      "word": "ACCESS",
      "meaning": "English meaning",
      "korMeaning": "Korean meaning",
      "pos": "Noun | Verb | Adjective | Adverb",
      "synonym": "optional",
      "antonym": "optional"
    }
  ]
}
```

Rules:
- `word` must be unique and A-Z only.
- `meaning`, `korMeaning`, and `pos` are required.
- `synonym` and `antonym` are optional.

Validation:

```powershell
python tool/validate_clue_words.py
```

Generation:

```powershell
python tool/generate_clue_assets.py --target-clue-size 8000 --target-anagram-rounds 4200
```

## Wordle/Crash assets

- `wordle_answers_4.txt`
- `wordle_answers_5.txt`
- `wordle_allowed_4.txt`
- `wordle_allowed_5.txt`
- `crash_words.txt`
- `anagram_rounds.json`

Regeneration script:

```powershell
python tool/generate_wordlists.py
```
