# Coal and bronze shield — reference pass v3

The user rejected the smooth coal surface and the flat brown shield. This pass replaces their visible artwork in the existing 2.5D character system. It does not change combat durability, collision geometry or damage. The face and feet remain independent. The shield remains an independent rig part with windup, recoil and inherited death momentum.

Generated with the **built-in imagegen tool**, using `work/enemy-concepts/materials-v1.png` as the visual reference. The RGB green-backed source files were copied unchanged into the project; the runtime shader removes the matte. The shield's source rectangle is sampled in the shader without raster cropping or stretching its proportions.

| Asset | Consumer |
|---|---|
| [enemy-coal-body-v3.png](/Users/user/projects/games/ordo/assets/enemy-coal-body-v3.png) | `enemy_reference.gd`, all coal material enemies and the wave portrait |
| [enemy-bronze-shield-v3.png](/Users/user/projects/games/ordo/assets/enemy-bronze-shield-v3.png) | `enemy_craft.gd`, standalone shield for brute/ram |

Original generated sources under `/Users/user/.codex/generated_images/01a09fdc-882b-7780-a07f-76e739a3c1ea/`: `exec-d88a8da1-0b26-41ae-90b2-6e4e61c4b789.png` (coal), `exec-8074b8dd-fe8a-4f19-8543-a9d9fa572f3f.png` (shield).

## Final coal prompt

Use case: precise-object-edit and background-extraction. Production isolated BODY layer for the first COAL creature in the supplied ORDO reference. Recreate the exact FIRST small coal character's compact rounded charcoal pebble body, WITHOUT its eyes, eye sockets, mouth or feet: cleanly replace those features with continuous natural charcoal material. Rounded slightly irregular near-spherical silhouette, rich soot-black and charcoal grey material, subtle natural porous pits and worn carbon grain, broad soft volume highlights from warm upper left with cool subtle rim on right. Realistic miniature lump of burnt charcoal, tactile, solid, charming, not grotesque. Include only two tiny natural grey felt bindings tucked into side seams, less than 3 percent of the surface. No big seams. Preserve the reference's restrained shallow pits and soft surface; no faceted low-poly geometry, no plasticine, no smooth plastic, no glossy ceramic, no plates, no crack network, no rubble aggregate, no rock crystals. The front face area is the SAME charcoal surface, not a painted black disc. No eyes or facial holes, mouth, feet, limbs, eyebrows, pupils, flame or smoke. Single isolated body only. Frontal view with a gentle view down onto top as in the reference, subtle egg-like asymmetry, centered and uncropped filling 85 percent of a square frame. RGB production CHROMA KEY background: perfectly uniform pure green RGB(0,255,0), no checkerboard, gradients, scenery, contact shadow on backdrop, or text. Detailed realistic 3D game render matching the supplied character exactly.

## Final shield prompt

Use case: precise-object-edit and background-extraction. Production isolated shield layer for ORDO. Use ONLY the bronze shield worn by the SECOND stone creature in the supplied reference. Faithfully recreate that exact little bowl-curved convex bronze shield, as if removed intact from the character: crescent bowl outline, nearly horizontal gently curved raised upper lip, broad rounded U-shaped lower edge, gently upturned pointed corners, dark inset forged bronze panel, thick rounded polished bevel along the entire perimeter, a single LARGE convex hemispherical bronze boss/rivet near the lower center. Tactile antique cast bronze, rich irregular warm brown and golden metal, tiny hammer marks and pits, fine worn scratches, restrained dark patina in recesses, bright narrow golden edge highlights. Clear three-dimensional curvature, metal thickness, contact-shadow under the raised rim, spherical reflective highlight on central boss, soft warm upper-left key and cool subtle right fill. This must be the substantial ornate material quality from the reference, NOT a smooth brown flat semicircle or a flat UI icon. Do not add new emblems or studs. One shield only, no creature, no eyes, no mouth, no body, no hands, no floor, no lettering, no extra objects. The camera looks at its outside convex front, matching the reference angle, with the top lip visible. Production RGB CHROMA KEY background: perfectly flat pure green RGB(0,255,0), no checkerboard, no gradients, no shadow on background, no vignette. Entire object centered and uncropped with generous green margin. Landscape composition 2:1, shield wide and shallow with width roughly 2.2 times its height. No transparency simulation. Preserve the exact reference art direction.



## Validation

Godot checks: enemy rigs 59, death motion 271, presentation 19, reference layout 25 — all passing. The death test now checks the face against the visible body and keeps the facial expression at its attachment's local origin; the obsolete fixed world-space height assumed the old 3D face layout.

Live captures: `work/enemy-motion/coal-shield-v3-035.png` (rest), `coal-shield-v3-110.png` (shield windup), `coal-shield-v3-236.png` (death), `coal-shield-v3.mp4` (5.5-second sequence), plus the ordinary gameplay scale in `boss-narrow-060.png`. These are actual engine renders, not new concept sheets. Physics and animations were checked; this does not claim arbitrary-view 3D models or measured real-time frame rate.
