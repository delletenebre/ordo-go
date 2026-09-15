# Character body layers from the approved reference

The user explicitly rejected the sparse procedural felt wrapping and the smooth stone body on 2026-09-15. The new bodies use detailed camera-facing artwork inside the 3D arena. Eyes, mouth, feet, bronze shield, physical contact shadows, motion, impact reactions and fire are independent live components. These are 2.5D character body layers, not newly authored full 3D models or a claim of pixel-identical reference reproduction.

The two feet reuse the original RGBA `enemy-parts/weaver/top-knot.png` and `enemy-parts/bulwark/foot-01.png` cutouts already in the project. They move as independent parts.

Both final RGB source images use a green matte removed in the runtime shader. The first imagegen extraction returned a painted checkerboard without an alpha channel, so it was rejected as a production transparency source. No manual raster editing or background-removal script was used.

| Asset | Consumer |
|---|---|
| `assets/enemy-felt-body-v2.png` | `scripts/enemy_reference.gd`, felt boss body |
| `assets/enemy-stone-body-v2.png` | `scripts/enemy_reference.gd`, brute and ram stone body |

Generated with the built-in imagegen tool. The approved reference was `design/references/enemy-materials-v1.png`. Final source outputs: `exec-ac3656b3-4496-4f45-8e43-63e357ddff68.png` and `exec-e16c98e9-ef58-4895-8ca4-a97bed38d4b8.png` in `/Users/user/.codex/generated_images/01a09fdc-882b-7780-a07f-76e739a3c1ea/`. Copied unchanged to the asset paths above.

## Boss body generation prompt

Use case: background-extraction and precise-object-edit. Production character body layer for the ORDO game, derived directly from the RIGHTMOST FELT BOSS in the supplied approved reference. Recreate ONLY that exact dense round dark wool yarn boss body and its small wrapped top knot at high fidelity: dark charcoal-brown matted wool and densely packed overlapping broad oatmeal three-ply twisted soft yarn bands, with fine curled loose fibers, realistic soft volume, detailed contact shading between strands, rounded silhouette, same asymmetric winding pattern and handcrafted tactile art direction. It must look like the reference boss, not a sparse cage, not a basket, not plastic tubing. Remove eyes, mouth and both feet entirely, cleanly replacing all face features with the underlying dark densely fibrous felt; leave a natural roughly oval central area of dark wool between the wraps where animated eyes and mouth will be added in the game. Keep the face area compact as in the reference, not a large blank smooth disc. No facial holes, black circles, pupils, eyes, glowing features, mouth or eyebrows. No feet, no floor, no contact shadow on the background, no scenery, no labels, no text. GENUINE TRANSPARENT RGBA background. One centered isolated body only, filling 88% of a square image, uncropped top knot and loose fibers, frontal view with a slight view down onto the top as in the reference, soft warm key from upper left and subtle cool rim, realistic game render. The result will be composited with independent animated facial features and feet in the live game, so fidelity to the supplied actual character is critical.

## Boss final matte edit prompt

Precise-object-edit for a production game sprite. Replace ONLY every light gray and white checkerboard background pixel around this wool body with a perfectly uniform pure vivid green RGB (0,255,0), including the checkerboard visible between loose silhouette fibers. This is a chroma-key source asset. Absolutely no checkerboard, no gray, no white, no scenery, no shadow on the green background. Preserve the wool body, its shape, top knot, detailed strands, front area and all material lighting exactly. Do not add eyes or mouth or feet. Flat uniform pure green backing all the way to each edge, no gradients, no text. The character remains exactly as supplied.

## Stone body generation prompt

Use case: background-extraction and precise-object-edit. Production character body layer for ORDO based directly on the SECOND character STONE in the approved reference. Isolate and faithfully recreate the same rounded egg-shaped slate stone body at high detail: weathered charcoal blue-grey stone, irregular worn mineral veins, tiny pits, softly rounded volumetric silhouette, single deeply carved diamond enclosing a spiral high on the forehead, rich realistic material shading. Remove the bronze shield, both feet, eyes, eye sockets and mouth ENTIRELY, reconstructing continuous naturally textured slate in those areas. The face and shield will be animated as separate pieces in the game. Retain only the rounded stone body and its recessed forehead carving. No smooth featureless blue plastic ball, no black painted face disc, no flat polygon, no limbs, no horns, no eyes, no mouth, no glowing features, no shield, no floor, no scenery, no shadow outside the object, no labels or text. GENUINE TRANSPARENT RGBA background. One centered single body filling 88% of a square image, uncropped. Frontal camera tilted gently down 15 degrees as in the reference, warm left key and subtle cool upper-right rim, detailed realistic tactile 3D game render. Match the reference character, not a redesign.

## Stone final matte edit prompt

Precise-object-edit for a production game sprite. Replace ONLY all the light gray and white checkerboard background around this stone body with perfectly uniform pure vivid green RGB (0,255,0), right up to the exact stone silhouette. This is a chroma-key source asset. No checkerboard, white or gray backdrop. Preserve the entire stone body, etched spiral diamond, shape, detailed weathered slate, highlights and lighting exactly unchanged. Do not add eyes, mouth, feet, horns or shield. No cast shadow on background. Flat solid green corner to corner around the body, no gradients, no text.



Coal and the bronze shield were replaced in a subsequent reference pass. See [coal-shield-v3.md](coal-shield-v3.md) for the current sources, exact prompts and integration.
