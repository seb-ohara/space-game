---
name: pixel-art-studio
description: Create, refine, and verify original pixel art game assets in ChatGPT. Use for low-resolution sprites, icons, modular tiles, sprite sheets, and requests for exact PNG dimensions, transparent edges, or a consistent game palette.
---

# Pixel Art Studio

Make sprites that read at the size they will be displayed. Use the chat's built-in image generation for creative work and its built-in Python or file tools for deterministic pixel placement, cleanup, export, and validation. Check which tools and files are available in the current chat. A rendered image in a message may need to be downloaded and reattached as a PNG before Python can read it.

## Establish the art direction

- Determine the subject, native canvas in pixels, camera angle, silhouette, and intended use. Treat a required palette, footprint, anchor, and pixel mask as separate constraints. Infer routine choices from the attached references or the project. If none are given, 32×32 is a starting point for a small icon or module and 64×64 for a more detailed sprite. Ask only when the missing detail materially changes the output.
- Use one to three relevant approved assets when available. Tell the image tool what to borrow from each, such as camera angle and bevel thickness from a hull tile, or color ramps from a reactor. For an edit, use the current master PNG as the primary reference. Keep the artwork's key landmarks, scale, and facing consistent across a set.
- In the prompt, describe the silhouette and two or three visual features that must survive at native size. Specify camera angle, lighting direction, and how to group light and shadow into solid pixel clusters. Request an isolated sprite with enough clear space around it and real transparency when needed. Keep text, presentation effects, decorative borders, and contact sheets out of the generation unless requested.

## Choose the production method

| Asset | Method |
|---|---|
| Organic or detailed sprite | Generate or edit with the built-in image tool. Work on one isolated sprite per image. Review alternate candidates if the initial silhouette, lighting, or view misses the brief. |
| Small geometric icon, tile, or attachment with an exact footprint | Draw directly into a native-resolution RGBA canvas with integer coordinates, solid fills, and simple pixel clusters. Apply supplied masks and edge templates as hard constraints. Use image generation for visual ideas or original interior detail when useful. |
| Animation or related facings | Start from one approved sprite. Use controlled layers for mechanical motion and glow. For more complex motion, use the available image or animation tools as a source, then inspect individual frames. Keep a common frame canvas and pivot. Assemble sheets from verified frames in order, with dimensions and playback timing. |

## Finish and check the asset

1. **Review the shape first.** Preview at the target size and at an integer zoom with nearest-neighbor scaling. Check the silhouette against the references. Regenerate or revise a wrong view or unreadable shape before spending time on cleanup.
2. **Build the native PNG.** If the source already lives on the intended grid, keep it there. For enlarged art with a regular, visible grid, recover the source cell size and origin before sampling one pixel per cell. For uncertain or drifting grids, compare a small number of plausible crops or sampling choices at native size. Redraw or regenerate when the features still break. Preserve proportions and place the result on the exact canvas with transparent padding as needed. Keep supplied anchors fixed across variants and frames.
3. **Apply color and alpha deliberately.** If the user supplies exact colors, map visible pixels to that palette and verify membership. Otherwise, only reduce colors when it helps the design. Check that color reduction keeps key accents and enough contrast. Use hard alpha for ordinary crisp sprites when appropriate and preserve graduated alpha for intentional glow or smoke. Inspect on both light and dark backgrounds. If an image arrives with a baked-in backdrop, use a transparent rerender, a deliberate mask, or edge-connected keying for a verified flat matte. Inspect the result for holes and halos.
4. **Verify what you deliver.** Reopen the actual PNG and check canvas size, alpha, and any specified palette, padding, edge masks, and anchors. Check atlas rectangles and playback if applicable. Return the native PNG and, when helpful, a separate enlarged preview. Keep project originals available. Describe any specification you could only check visually. If the raster or execution tool is unavailable, share the candidate and state what needs to happen before it can be verified.

Use [scripts/sprite_png.py](scripts/sprite_png.py) when Python with Pillow is available. `inspect` reports dimensions, alpha bounds, partial alpha, and visible colors. `finish` crops, optionally samples a known aligned grid, fits and anchors a still sprite, then writes a PNG and optional preview. Use `--help` for arguments. The helper expects actual source transparency for transparent sprites. Use `--opaque` for fully opaque tiles. Use direct pixel drawing or custom Python for protected masks, exact edge matching, animation packing, or locating a grid whose origin is uncertain.

## Example brief

> Make a 32×32 top-down industrial reactor for Drift. Use my hull tile for the camera angle and stepped metal bevels, and my power cell for the amber accent. Give it a chunky rectangular silhouette with two cooling fins and one readable light at gameplay size. Center it with a one-pixel transparent margin. Return the native PNG and a 6× nearest-neighbor preview.
