#!/usr/bin/env python3
"""Generate static Swift preview artwork fixtures from DebugAssets.xcassets.

The output is intended to be pasted into PreviewContainer.swift. It embeds
downsized JPEG data and precomputed color metadata so SwiftUI previews can pick
random album art without doing image analysis or image re-encoding at refresh
time.
"""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import statistics
import subprocess
import tempfile
import zlib


def run_sips(*args: str) -> None:
    subprocess.run(
        ["sips", *args],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def image_path(imageset: pathlib.Path) -> pathlib.Path | None:
    contents = json.loads((imageset / "Contents.json").read_text())
    for image in contents.get("images", []):
        filename = image.get("filename")
        if filename:
            return imageset / filename
    return None


def png_scanlines(data: bytes) -> tuple[int, int, list[tuple[int, int, int]]]:
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Expected PNG data")

    offset = 8
    width = height = bit_depth = color_type = None
    chunks: list[bytes] = []

    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += 12 + length

        if chunk_type == b"IHDR":
            width = int.from_bytes(chunk_data[0:4], "big")
            height = int.from_bytes(chunk_data[4:8], "big")
            bit_depth = chunk_data[8]
            color_type = chunk_data[9]
        elif chunk_type == b"IDAT":
            chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None or bit_depth != 8 or color_type not in (2, 6):
        raise ValueError("Only 8-bit RGB/RGBA PNGs are supported")

    channels = 4 if color_type == 6 else 3
    row_length = width * channels
    raw = zlib.decompress(b"".join(chunks))
    rows: list[bytearray] = []
    cursor = 0

    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor : cursor + row_length])
        cursor += row_length
        previous = rows[-1] if rows else bytearray(row_length)

        for index in range(row_length):
            left = row[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0

            if filter_type == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_type == 2:
                row[index] = (row[index] + up) & 0xFF
            elif filter_type == 3:
                row[index] = (row[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                predictor = paeth(left, up, up_left)
                row[index] = (row[index] + predictor) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"Unsupported PNG filter: {filter_type}")

        rows.append(row)

    pixels: list[tuple[int, int, int]] = []
    for row in rows:
        for index in range(0, row_length, channels):
            pixels.append((row[index], row[index + 1], row[index + 2]))

    return width, height, pixels


def paeth(left: int, up: int, up_left: int) -> int:
    prediction = left + up - up_left
    left_distance = abs(prediction - left)
    up_distance = abs(prediction - up)
    up_left_distance = abs(prediction - up_left)

    if left_distance <= up_distance and left_distance <= up_left_distance:
        return left
    if up_distance <= up_left_distance:
        return up
    return up_left


def luminance(pixel: tuple[int, int, int]) -> float:
    red, green, blue = pixel
    return (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255


def hex_color(pixel: tuple[int, int, int]) -> str:
    return f"#{pixel[0]:02X}{pixel[1]:02X}{pixel[2]:02X}"


def representative_colors(pixels: list[tuple[int, int, int]]) -> tuple[str, list[str], bool]:
    average = tuple(round(statistics.fmean(channel)) for channel in zip(*pixels))
    sorted_pixels = sorted(pixels, key=luminance)
    dark = sorted_pixels[len(sorted_pixels) // 5]
    light = sorted_pixels[(len(sorted_pixels) * 4) // 5]
    colors = [hex_color(average), hex_color(light), hex_color(dark)]
    deduped = list(dict.fromkeys(colors))

    return colors[0], deduped, luminance(average) < 0.5


def swift_string_literal(value: str, indentation: str) -> str:
    chunks = [value[index : index + 96] for index in range(0, len(value), 96)]
    body = "\n".join(f"{indentation}{chunk}" for chunk in chunks)
    return f'"""\n{body}\n{indentation[:-4]}"""'


def generate_fixture(source: pathlib.Path, max_size: int, jpeg_quality: int) -> dict[str, object]:
    with tempfile.TemporaryDirectory() as temporary_directory:
        temp = pathlib.Path(temporary_directory)
        jpeg_path = temp / "preview.jpg"
        png_path = temp / "sample.png"

        run_sips(
            "-Z",
            str(max_size),
            "-s",
            "format",
            "jpeg",
            "-s",
            "formatOptions",
            str(jpeg_quality),
            str(source),
            "--out",
            str(jpeg_path),
        )
        run_sips("-Z", "16", "-s", "format", "png", str(source), "--out", str(png_path))

        _, _, pixels = png_scanlines(png_path.read_bytes())
        dominant, colors, is_dark = representative_colors(pixels)

        return {
            "name": source.parent.stem.removesuffix(".imageset"),
            "base64": base64.b64encode(jpeg_path.read_bytes()).decode("ascii"),
            "dominant": dominant,
            "colors": colors,
            "isDark": is_dark,
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--assets",
        default="Baila/DebugAssets.xcassets",
        type=pathlib.Path,
        help="Path to the debug asset catalog.",
    )
    parser.add_argument("--max-size", default=768, type=int)
    parser.add_argument("--jpeg-quality", default=78, type=int)
    args = parser.parse_args()

    fixtures = []
    for imageset in sorted(args.assets.glob("*.imageset"), key=lambda path: path.stem):
        source = image_path(imageset)
        if source is not None:
            fixtures.append(generate_fixture(source, args.max_size, args.jpeg_quality))

    print("private struct PreviewArtworkFixture {")
    print("    let name: String")
    print("    let dominantColorHex: String")
    print("    let dominantColorHexes: [String]")
    print("    let isDark: Bool")
    print("    let albumArtBase64: String")
    print("")
    print("    var albumArt: Data? {")
    print("        Data(base64Encoded: albumArtBase64, options: .ignoreUnknownCharacters)")
    print("    }")
    print("}")
    print("")
    print("private static let artworkFixtures: [PreviewArtworkFixture] = [")
    for fixture in fixtures:
        colors = ", ".join(f'"{color}"' for color in fixture["colors"])
        print("    PreviewArtworkFixture(")
        print(f'        name: "{fixture["name"]}",')
        print(f'        dominantColorHex: "{fixture["dominant"]}",')
        print(f"        dominantColorHexes: [{colors}],")
        print(f'        isDark: {str(fixture["isDark"]).lower()},')
        print("        albumArtBase64: " + swift_string_literal(fixture["base64"], "            "))
        print("    ),")
    print("]")


if __name__ == "__main__":
    main()
