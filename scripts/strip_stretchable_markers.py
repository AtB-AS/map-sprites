#!/usr/bin/env python3
"""
Strips the paint (fill/stroke) from Mapbox stretchable-icon marker elements
in exported SVGs, while leaving their id and geometry untouched.

Figma drops fully-transparent shapes when exporting to SVG, so the marker
rects for `content`/`stretchX`/`stretchY` (see
https://docs.mapbox.com/style-spec/reference/sprite/) have to be exported
with a visible, solid-ish fill and then made invisible afterwards - that's
what this script does. martin/spreet only look at each marker's bounding box
via its `id`, so removing the paint has no effect on the generated sprite
metadata.

Usage:
    strip_stretchable_markers.py <src_dir> <dst_dir>

Every .svg file under <src_dir> is processed into the same relative path
under <dst_dir>. Files with no marker elements are copied through unchanged.
"""

import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

# Matches the exact ids martin/spreet look for:
# mapbox-content, mapbox-stretch, mapbox-stretch-x[-N], mapbox-stretch-y[-N]
MARKER_ID_RE = re.compile(r"^mapbox-(content|stretch(-[xy](-\d+)?)?)$")

# Figma appends `_2`, `_3`, ... to de-duplicate layers with the same name,
# which silently breaks the convention above (spreet will never find e.g.
# "mapbox-content_2"). Flag these so they can be renamed by hand in Figma.
SUSPECT_ID_RE = re.compile(r"^mapbox-(content|stretch(-[xy])?)(-\d+)?_\d+$")

PAINT_ATTRS = ("fill", "fill-opacity", "stroke", "stroke-width", "stroke-opacity")


def strip_paint(elem: ET.Element) -> None:
    for attr in PAINT_ATTRS:
        elem.attrib.pop(attr, None)
    elem.attrib.pop("style", None)
    elem.set("fill", "none")
    elem.set("stroke", "none")


def process_svg(src_path: Path) -> tuple[bytes, list[str]]:
    warnings = []
    tree = ET.parse(src_path)
    root = tree.getroot()

    seen_marker_ids = set()
    touched = False
    for elem in root.iter():
        elem_id = elem.get("id")
        if not elem_id:
            continue
        if MARKER_ID_RE.match(elem_id):
            if elem_id in seen_marker_ids:
                warnings.append(
                    f"duplicate marker id {elem_id!r} - only one will be used by spreet"
                )
            seen_marker_ids.add(elem_id)
            strip_paint(elem)
            touched = True
        elif SUSPECT_ID_RE.match(elem_id):
            warnings.append(
                f"id {elem_id!r} looks like a Figma auto-deduplicated marker "
                "name (e.g. two layers were both named 'mapbox-content') - "
                "rename it in Figma so it matches the plain mapbox-* convention"
            )

    if not touched:
        return src_path.read_bytes(), warnings

    return ET.tostring(root, encoding="unicode").encode("utf-8"), warnings


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1

    src_dir, dst_dir = Path(sys.argv[1]), Path(sys.argv[2])
    if not src_dir.is_dir():
        print(f"error: {src_dir} is not a directory", file=sys.stderr)
        return 1

    dst_dir.mkdir(parents=True, exist_ok=True)
    exit_code = 0
    for src_path in sorted(src_dir.glob("*.svg")):
        dst_path = dst_dir / src_path.name
        try:
            content, warnings = process_svg(src_path)
        except ET.ParseError as e:
            print(f"error: failed to parse {src_path}: {e}", file=sys.stderr)
            exit_code = 1
            continue

        dst_path.write_bytes(content)
        for warning in warnings:
            print(f"warning: {src_path.name}: {warning}", file=sys.stderr)
            exit_code = 1

    # carry over any non-svg files (shouldn't normally be any, but avoids
    # silently dropping something martin would otherwise have seen)
    for other_path in src_dir.iterdir():
        if other_path.is_file() and other_path.suffix.lower() != ".svg":
            shutil.copy2(other_path, dst_dir / other_path.name)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
