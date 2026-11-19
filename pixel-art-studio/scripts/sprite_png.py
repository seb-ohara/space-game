#!/usr/bin/env python3
"""Inspect and finish a single pixel-art PNG with Pillow."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re

from PIL import Image


def dimensions(value):
    match = re.fullmatch(r"([1-9][0-9]*)x([1-9][0-9]*)", value)
    if not match:
        raise argparse.ArgumentTypeError("Use dimensions such as 32x32.")
    return tuple(map(int, match.groups()))


def crop_box(value):
    match = re.fullmatch(r"(\d+),(\d+),([1-9][0-9]*),([1-9][0-9]*)", value)
    if not match:
        raise argparse.ArgumentTypeError("Use x,y,width,height with no spaces.")
    x, y, width, height = map(int, match.groups())
    return x, y, x + width, y + height


def parse_palette(value):
    colors = [color.strip().removeprefix("#") for color in value.split(",")]
    if any(not re.fullmatch(r"[0-9a-fA-F]{6}", color) for color in colors):
        raise argparse.ArgumentTypeError("Use comma-separated six-digit RGB hex colors.")
    return list(dict.fromkeys(tuple(bytes.fromhex(color)) for color in colors))


def report(image):
    alpha = image.getchannel("A")
    counts = alpha.histogram()
    return {
        "width": image.width,
        "height": image.height,
        "alpha_bbox_xyxy_exclusive": alpha.getbbox(),
        "transparent_pixels": counts[0],
        "partial_alpha_pixels": sum(counts[1:255]),
        "visible_colors": len({pixel[:3] for pixel in image.getdata() if pixel[3]}),
    }


def recolor(image, palette=None, color_limit=None):
    pixels = list(image.getdata())
    colors = Counter(pixel[:3] for pixel in pixels if pixel[3])
    if not colors:
        return
    if palette:
        def distance(color, candidate):
            return sum((a - b) ** 2 for a, b in zip(color, candidate))

        mapped = {color: min(palette, key=lambda entry: distance(color, entry)) for color in colors}
    elif color_limit and len(colors) > color_limit:
        palette_source = Image.new("RGB", (sum(colors.values()), 1))
        palette_source.putdata([pixel[:3] for pixel in pixels if pixel[3]])
        reduced = palette_source.quantize(colors=color_limit, method=Image.Quantize.MEDIANCUT).convert("RGB")
        mapped = dict(zip(palette_source.getdata(), reduced.getdata()))
    else:
        return
    image.putdata([(*mapped[pixel[:3]], pixel[3]) if pixel[3] else (0, 0, 0, 0) for pixel in pixels])


def finish(image, args):
    if args.crop:
        if args.crop[2] > image.width or args.crop[3] > image.height:
            raise ValueError("The crop must be inside the source.")
        image = image.crop(args.crop)

    if args.alpha_threshold is not None:
        alpha = image.getchannel("A").point([0] * args.alpha_threshold + [255] * (256 - args.alpha_threshold))
        image.putalpha(alpha)

    if args.cell_size is not None:
        step = args.cell_size
        if image.width % step or image.height % step:
            raise ValueError("The source or aligned crop must contain whole grid cells.")
        image = image.resize((image.width // step, image.height // step), Image.Resampling.NEAREST)

    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("No visible pixels remain.")
    if args.opaque:
        if args.margin or alpha.getextrema() != (255, 255):
            raise ValueError("An opaque tile needs a fully opaque source and a zero margin.")
    elif alpha.getextrema()[0] != 0:
        raise ValueError("Source has no fully transparent pixels. Supply a transparent source or crop, or use --opaque for a tile.")

    if not args.keep_source_canvas and not args.opaque:
        image = image.crop(bounds)

    width, height = args.canvas
    area_w = width - 2 * args.margin
    area_h = height - 2 * args.margin
    if area_w < 1 or area_h < 1:
        raise ValueError("The margin leaves no usable canvas area.")
    ratio = min(area_w / image.width, area_h / image.height, 1)
    if ratio < 1:
        if args.cell_size is not None or args.keep_source_canvas or args.opaque:
            raise ValueError("The exact source grid does not fit. Adjust the crop, canvas, or margin.")
        image = image.resize(
            (max(1, round(image.width * ratio)), max(1, round(image.height * ratio))),
            Image.Resampling.NEAREST,
        )

    if args.opaque and image.size != args.canvas:
        raise ValueError("The opaque tile must fill the canvas after grid recovery.")
    x = (width - image.width) // 2 if args.anchor != "top-left" else args.margin
    y = {
        "center": (height - image.height) // 2,
        "bottom-center": height - args.margin - image.height,
        "top-left": args.margin,
    }[args.anchor]
    output = Image.new("RGBA", args.canvas)
    output.paste(image, (x, y))
    if output.getchannel("A").getbbox() is None:
        raise ValueError("The sprite disappeared during sampling. Try a different crop or sample grid.")
    recolor(output, args.palette, args.max_colors)
    return output


def bounded_int(low, high):
    def parse(value):
        number = int(value)
        if not low <= number <= high:
            raise argparse.ArgumentTypeError(f"Use an integer from {low} to {high}.")
        return number
    return parse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    inspect = subcommands.add_parser("inspect", help="Read size, alpha bounds, and color count.")
    inspect.add_argument("source", type=Path)
    export = subcommands.add_parser("finish", help="Export a native sprite PNG.")
    export.add_argument("source", type=Path)
    export.add_argument("output", type=Path)
    export.add_argument("--canvas", type=dimensions, required=True, help="Exact output dimensions, e.g. 32x32.")
    export.add_argument("--crop", type=crop_box, help="Source crop x,y,width,height before sampling.")
    export.add_argument("--cell-size", type=bounded_int(1, 4096), help="Known aligned source pixel-block size.")
    export.add_argument("--anchor", choices=["center", "bottom-center", "top-left"], default="center")
    export.add_argument("--margin", type=bounded_int(0, 4096), default=0)
    export.add_argument("--keep-source-canvas", action="store_true", help="Preserve padding and disable fit-down.")
    export.add_argument("--opaque", action="store_true", help="Require a fully opaque tile that fills the canvas.")
    export.add_argument("--alpha-threshold", type=bounded_int(1, 255), help="Make alpha binary at this threshold.")
    colors = export.add_mutually_exclusive_group()
    colors.add_argument("--palette", type=parse_palette, help="Comma-separated exact RGB hex colors.")
    colors.add_argument("--max-colors", type=bounded_int(1, 256), help="Maximum distinct visible colors.")
    export.add_argument("--preview", type=Path, help="Separate zoomed PNG.")
    export.add_argument("--zoom", type=bounded_int(2, 16), default=6)
    args = parser.parse_args()

    try:
        with Image.open(args.source) as source:
            if getattr(source, "n_frames", 1) != 1:
                raise ValueError("Use a single still frame.")
            image = source.convert("RGBA")
        if args.command == "inspect":
            print(json.dumps(report(image)))
            return
        paths = [args.source, args.output] + ([args.preview] if args.preview else [])
        if len({path.resolve() for path in paths}) != len(paths):
            raise ValueError("Use different paths for the source, native PNG, and preview.")
        if args.output.exists() or (args.preview and args.preview.exists()):
            raise ValueError("Choose new output paths to preserve previous results.")
        output = finish(image, args)
        output.save(args.output, format="PNG")
        if args.preview:
            preview_size = (output.width * args.zoom, output.height * args.zoom)
            output.resize(preview_size, Image.Resampling.NEAREST).save(args.preview, format="PNG")
        with Image.open(args.output) as saved:
            print(json.dumps(report(saved.convert("RGBA"))))
    except (OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
