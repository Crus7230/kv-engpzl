"""Package Flutter-rendered motion frames as GIFs without changing game assets.

Run discovery_motion_preview_test.dart first. Requires existing Pillow; this
script installs nothing. The capture manifest defines the exact frame count.
"""

import json
from pathlib import Path

from PIL import Image


def assemble(directory: Path) -> None:
    manifest = json.loads((directory / "capture.json").read_text(encoding="utf-8"))
    frames = []
    for index in range(manifest["frames"]):
        with Image.open(directory / f"frame-{index:03d}.png") as source:
            frames.append(source.convert("RGB"))
    # One shared palette keeps static text/background colors stable across
    # frames. Sample the full sequence so gem shards/power colors are included.
    samples = frames[:: max(1, len(frames) // 8)]
    palette_sheet = Image.new("RGB", (frames[0].width, frames[0].height * len(samples)))
    for index, sample in enumerate(samples):
        palette_sheet.paste(sample, (0, index * frames[0].height))
    palette = palette_sheet.quantize(colors=256)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    durations = [manifest["frameMilliseconds"]] * len(indexed)
    durations[0] = 450
    durations[-1] = 900
    target = directory.parent / f"{directory.name}_800x360_flutter-simulated.gif"
    indexed[0].save(
        target,
        save_all=True,
        append_images=indexed[1:],
        duration=durations,
        loop=0,
        disposal=1,
        optimize=True,
    )
    for frame in frames + indexed:
        frame.close()
    palette.close()
    palette_sheet.close()
    print(f"{target}: {manifest['frames']} frames, {manifest['turnMilliseconds']} ms turn")


if __name__ == "__main__":
    preview_root = Path(__file__).resolve().parents[1] / "build" / "previews"
    for name in ("r1-swap-discovery", "r1-power-cascade", "r1-power-birth-cascade"):
        assemble(preview_root / f"motion-{name}")
