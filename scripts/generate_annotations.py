#!/usr/bin/env python3
"""Generate a large number of Web Annotation JSON files for stress-testing.

Outputs README-style annotations:
- No top-level "id" field
- "type": "Annotation"
- "motivation": "highlighting" or "commenting"
- "body": {"type":"TextualBody","value":...,"purpose":"commenting"}
- "target": "https://example.com/iiif/canvas/<n>#xywh=x,y,w,h"

By default, files are written under ./annotations/<container>/<slug>.json
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Config:
    out_dir: Path
    total: int
    containers: int
    prefix: str
    start_index: int
    seed: int
    canvas_base_url: str
    max_x: int
    max_y: int
    max_w: int
    max_h: int
    min_w: int
    min_h: int


def _positive_int(value: str) -> int:
    try:
        n = int(value)
    except ValueError as e:
        raise argparse.ArgumentTypeError(str(e))
    if n <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return n


def _non_negative_int(value: str) -> int:
    try:
        n = int(value)
    except ValueError as e:
        raise argparse.ArgumentTypeError(str(e))
    if n < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return n


def _build_annotation(index: int, *, rng: random.Random, cfg: Config) -> dict:
    motivation = "highlighting" if (index % 2 == 0) else "commenting"
    body_value = (
        f"Important passage #{index}" if motivation == "highlighting" else f"Comment #{index}"
    )

    x = rng.randint(0, cfg.max_x)
    y = rng.randint(0, cfg.max_y)
    w = rng.randint(cfg.min_w, cfg.max_w)
    h = rng.randint(cfg.min_h, cfg.max_h)

    target = f"{cfg.canvas_base_url}#xywh={x},{y},{w},{h}"

    return {
        "type": "Annotation",
        "motivation": motivation,
        "body": {
            "type": "TextualBody",
            "value": body_value,
            "purpose": "commenting",
        },
        "target": target,
    }


def _container_name(i: int, cfg: Config) -> str:
    if cfg.containers == 1:
        return f"{cfg.prefix}-canvas"
    width = max(2, int(math.log10(cfg.containers)) + 1)
    return f"{cfg.prefix}-canvas-{i:0{width}d}"


def _slug(i: int, cfg: Config) -> str:
    # Keep lexicographic order stable.
    width = max(4, int(math.log10(cfg.total + cfg.start_index + 1)) + 1)
    return f"annotation-{i:0{width}d}.json"


def generate(cfg: Config) -> None:
    cfg.out_dir.mkdir(parents=True, exist_ok=True)

    rng = random.Random(cfg.seed)

    per_container = int(math.ceil(cfg.total / cfg.containers))
    written = 0

    for container_idx in range(cfg.containers):
        container = _container_name(container_idx + 1, cfg)
        container_dir = cfg.out_dir / container
        container_dir.mkdir(parents=True, exist_ok=True)

        for j in range(per_container):
            if written >= cfg.total:
                break
            index = cfg.start_index + written
            annotation = _build_annotation(index, rng=rng, cfg=cfg)
            filename = _slug(index, cfg)
            out_path = container_dir / filename

            # Write compact JSON to reduce IO/storage overhead.
            out_path.write_text(json.dumps(annotation, separators=(",", ":")) + "\n", encoding="utf-8")
            written += 1

    print(f"Wrote {written} annotations into {cfg.containers} containers under: {cfg.out_dir}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate many README-style Web Annotation JSON files for stress-testing."
    )
    parser.add_argument(
        "--out",
        default="./annotations",
        help="Output directory (default: ./annotations)",
    )
    parser.add_argument(
        "--total",
        type=_positive_int,
        default=1000,
        help="Total number of annotations to generate (default: 1000)",
    )
    parser.add_argument(
        "--containers",
        type=_positive_int,
        default=10,
        help="Number of containers (directories) to spread annotations across (default: 10)",
    )
    parser.add_argument(
        "--prefix",
        default="stress",
        help="Container name prefix (default: stress)",
    )
    parser.add_argument(
        "--start-index",
        type=_non_negative_int,
        default=1,
        help="Starting number used in generated values/slugs (default: 1)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=1,
        help="Random seed for deterministic output (default: 1)",
    )
    parser.add_argument(
        "--canvas-base-url",
        default="https://example.com/iiif/canvas/1",
        help='Base URL for the "target" field, before #xywh=... (default: https://example.com/iiif/canvas/1)',
    )

    parser.add_argument("--max-x", type=_positive_int, default=5000)
    parser.add_argument("--max-y", type=_positive_int, default=5000)
    parser.add_argument("--min-w", type=_positive_int, default=10)
    parser.add_argument("--min-h", type=_positive_int, default=10)
    parser.add_argument("--max-w", type=_positive_int, default=800)
    parser.add_argument("--max-h", type=_positive_int, default=800)

    args = parser.parse_args()

    out_dir = Path(args.out).resolve()
    cfg = Config(
        out_dir=out_dir,
        total=args.total,
        containers=args.containers,
        prefix=args.prefix,
        start_index=args.start_index,
        seed=args.seed,
        canvas_base_url=args.canvas_base_url,
        max_x=args.max_x,
        max_y=args.max_y,
        min_w=args.min_w,
        min_h=args.min_h,
        max_w=args.max_w,
        max_h=args.max_h,
    )

    # Safety: prevent a common footgun where someone points at repo root.
    if cfg.out_dir == Path("/"):
        raise SystemExit("Refusing to write to /")

    generate(cfg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
