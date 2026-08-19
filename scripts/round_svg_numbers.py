#!/usr/bin/env python3
"""
Rounds numeric values in SVG files to a fixed precision, in place.

Every time an unchanged design is re-exported from Figma, the numbers in its
SVG (path data, coordinates, transforms, ...) come out with slightly
different floating point noise - e.g. 20.4598 one export, 20.4594 the next -
even though nothing actually changed. That makes every sprite_assets/*.svg
show up as modified on each re-export, with a diff nobody can meaningfully
review.

Rounding every numeric attribute to a fixed, small number of decimal places
absorbs that noise: two exports of the same design converge on the same
rounded numbers and produce no diff, while the rounding itself is far below
one pixel at these icon sizes and has no visible effect.

Usage:
    round_svg_numbers.py <dir> [<dir> ...]

Every .svg file found recursively under the given directories is rounded and
overwritten in place. Files that need no changes are left untouched.
"""

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

PRECISION = 2

# Only attributes that are purely numeric (or a list of numbers/coordinates)
# are touched. Everything else (id, fill, filter="url(#...)", fill-rule, ...)
# is left completely alone.
NUMERIC_ATTRS = {
    "x", "y", "width", "height", "cx", "cy", "r", "rx", "ry",
    "x1", "y1", "x2", "y2", "fx", "fy", "fr",
    "d", "points", "viewBox", "offset",
    "transform", "gradientTransform", "patternTransform",
    "stroke-width", "stroke-dasharray", "stroke-dashoffset", "stroke-miterlimit",
    "opacity", "fill-opacity", "stroke-opacity", "stop-opacity", "flood-opacity",
    "stdDeviation", "dx", "dy", "values",
}

NUMBER_RE = re.compile(r"-?\d*\.?\d+(?:[eE][+-]?\d+)?")


def round_number(match: re.Match) -> str:
    value = round(float(match.group()), PRECISION)
    if value == 0:
        value = 0.0  # normalize -0.0
    text = f"{value:.{PRECISION}f}".rstrip("0").rstrip(".")
    return text if text else "0"


def process_svg(path: Path) -> tuple[bytes, bool]:
    original = path.read_bytes()
    tree = ET.parse(path)
    root = tree.getroot()

    changed = False
    for elem in root.iter():
        for attr in NUMERIC_ATTRS:
            value = elem.get(attr)
            if value is None:
                continue
            rounded = NUMBER_RE.sub(round_number, value)
            if rounded != value:
                elem.set(attr, rounded)
                changed = True

    if not changed:
        return original, False

    return ET.tostring(root, encoding="unicode").encode("utf-8"), True


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1

    dirs = [Path(arg) for arg in sys.argv[1:]]
    for d in dirs:
        if not d.is_dir():
            print(f"error: {d} is not a directory", file=sys.stderr)
            return 1

    touched = 0
    total = 0
    for d in dirs:
        for path in sorted(d.rglob("*.svg")):
            total += 1
            try:
                content, changed = process_svg(path)
            except ET.ParseError as e:
                print(f"error: failed to parse {path}: {e}", file=sys.stderr)
                return 1

            if changed:
                path.write_bytes(content)
                touched += 1
                print(f"rounded: {path}")

    print(f"done: {touched}/{total} file(s) rounded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
