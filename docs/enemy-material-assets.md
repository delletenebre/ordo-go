# Enemy material assets, 2026-09-15

The approved reference is `design/references/enemy-materials-v1.png`, supplied again by the user as `codex-clipboard-bdae7be6-d990-4339-9cd0-1b971012d244.png`. Production maps were generated using the built-in imagegen tool, copied unchanged into the project, and used on live 3D geometry. Ceramic uses this map directly on live 3D geometry. Felt now also uses a detailed illustrated body layer after the user rejected the procedural wrapping; see `enemy-reference-layers.md`.

| Asset | Consumer |
|---|---|
| `assets/enemy-celadon-v1.png` | `enemy_materials.gd`, triplanar color and relief in `enemy_surface.gdshader`, ceramic body, feet, crown and death shards |
| `assets/enemy-felt-v1.png` | `enemy_materials.gd` and `enemy_craft.gd`, dense felt base and twisted yarn |

Original tool outputs remain in `/Users/user/.codex/generated_images/01a09fdc-882b-7780-a07f-76e739a3c1ea/`: `exec-24d2f1d5-d699-43b0-a17e-7916afd5ad0e.png` (ceramic), `exec-107a4681-ffe2-46ed-a852-90e8172d6268.png` (felt). Both reference the approved concept image as a material reference.

## Final prompt: ceramic

Use case: stylized-concept. Asset type: production PBR color texture, square seamless tile for the celadon ceramic enemy in the supplied reference. Reference image is style and material reference ONLY. Generate only a perfectly flat, orthographic, edge-to-edge material swatch of its aged sage-green/celadon ceramic glaze: subtly mottled pale desaturated green, dense tiny irregular brown iron flecks, sparse rubbed earthen ochre areas and minute pinholes, nuanced handcrafted fired clay. Fine photographic micro-detail, tactile realistic material matching the third character. Neutral even diffuse illumination, no directional shadows, no bright specular hotspot, no perspective, no sphere, no character, no eyes, no mouth, no floor, no text, no border. Seamlessly tileable in both axes. The texture will be wrapped onto a live 3D character with its own lighting; do not bake large-scale volume or illumination into the map.

## Final prompt: felt

Use case: stylized-concept. Asset type: production square seamlessly tileable PBR color material texture for dark wool felt base of the rightmost yarn boss in the supplied reference. Reference is material/style reference ONLY. Flat edge-to-edge extreme macro material swatch of dense compressed charcoal-brown and warm taupe wool, visibly tangled tiny soft curly wool fibers, densely packed and tactile, no bald areas. Same handcrafted natural wool as under the thick ropes of the rightmost character. Exclude the thick ropes themselves; only fine soft matted underfelt, realistic irregular fiber depth, mildly variegated muted soot-brown palette, low contrast. Uniform diffuse neutral lighting, no shadows/lighting gradient, no perspective, no object/sphere/character, no face, no eyes/mouth, no text, no border. Tileable in both directions. This will supply a live shader, not be shown as a new concept.
