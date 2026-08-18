#!/usr/bin/env python3
"""Tests for strip_stretchable_markers.py. Run with: python3 -m unittest discover scripts"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from strip_stretchable_markers import process_svg

SVG_OPEN = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
SVG_CLOSE = "</svg>"


class ProcessSvgTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def write_svg(self, body: str) -> Path:
        path = Path(self.tmp.name) / "test.svg"
        path.write_text(SVG_OPEN + body + SVG_CLOSE)
        return path

    def test_marker_fill_is_stripped(self):
        path = self.write_svg(
            '<rect id="mapbox-content" x="1" y="2" width="3" height="4" '
            'fill="#FF00FF" fill-opacity="0.5"/>'
        )
        content, warnings = process_svg(path)
        svg = content.decode()

        self.assertEqual(warnings, [])
        self.assertIn('id="mapbox-content"', svg)
        self.assertIn('fill="none"', svg)
        self.assertIn('stroke="none"', svg)
        # geometry must be untouched
        for attr in ('x="1"', 'y="2"', 'width="3"', 'height="4"'):
            self.assertIn(attr, svg)
        self.assertNotIn("#FF00FF", svg)
        self.assertNotIn("fill-opacity", svg)

    def test_numbered_stretch_ids_are_stripped(self):
        path = self.write_svg(
            '<rect id="mapbox-stretch-x-1" width="1" height="1" fill="red"/>'
            '<rect id="mapbox-stretch-y" width="1" height="1" fill="red"/>'
        )
        content, warnings = process_svg(path)
        svg = content.decode()

        self.assertEqual(warnings, [])
        self.assertEqual(svg.count('fill="none"'), 2)

    def test_non_marker_ids_are_untouched(self):
        path = self.write_svg(
            '<path id="Union" d="M0 0 L1 1" fill="white"/>'
        )
        content, warnings = process_svg(path)
        svg = content.decode()

        self.assertEqual(warnings, [])
        self.assertIn('fill="white"', svg)

    def test_file_without_markers_is_byte_identical(self):
        path = self.write_svg('<path id="Union" d="M0 0 L1 1" fill="white"/>')
        original = path.read_bytes()

        content, warnings = process_svg(path)

        self.assertEqual(warnings, [])
        self.assertEqual(content, original)

    def test_duplicate_marker_id_warns(self):
        path = self.write_svg(
            '<rect id="mapbox-content" width="1" height="1" fill="red"/>'
            '<rect id="mapbox-content" width="2" height="2" fill="red"/>'
        )
        _, warnings = process_svg(path)

        self.assertEqual(len(warnings), 1)
        self.assertIn("duplicate marker id", warnings[0])

    def test_figma_dedup_suffix_is_flagged_not_stripped(self):
        path = self.write_svg(
            '<rect id="mapbox-content_2" width="1" height="1" fill="red"/>'
        )
        content, warnings = process_svg(path)
        svg = content.decode()

        self.assertEqual(len(warnings), 1)
        self.assertIn("mapbox-content_2", warnings[0])
        # not a recognized marker id, so it must be left alone
        self.assertIn('fill="red"', svg)


if __name__ == "__main__":
    unittest.main()
