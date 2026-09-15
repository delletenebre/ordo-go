# Approved enemy concepts: movement and material response

The user selected `design/references/enemy-materials-v1.png` on 2026-09-15. The four material families are compact coal, dark stone with a bronze shield, celadon ceramic, and a wound-felt boss. Preserve internally glowing eyes without pupils, a separate expressive mouth, two attached feet and a restrained silhouette.

## Model before implementation

Existing combat masses remain 0.7 / 2.2 / 1.0 / 4.0. For the same impulse J=2, Δv=J/m is respectively 2.86 / 0.91 / 2.00 / 0.50. Animation must retain that difference; horizontal corpse velocity already includes mass and must not be divided by mass again. HP, damage and wave counts do not change.

| Material | Maximum visual compression | Approximate settle | Fragment bounce | Floor friction |
|---|---:|---:|---:|---:|
| Coal | 3.5% | 0.22 s | 0.18 | 0.84 |
| Stone | 0.8% | 0.30 s | 0.08 | 0.94 |
| Ceramic | 1.2% | 0.24 s | 0.10 | 0.87 |
| Felt | 12% | 0.55 s | 0.28 | 0.92 |

Use an exact critically damped spring with ω=4.6/settle for impact recovery. Gait advances with distance travelled, not a decorative clock. The foot remains planted through 62% of its cycle; only its return stroke lifts. Breathing is confined to felt. Anticipation follows the actual enemy phase, contact follows `fired` or impact events, and stunned enemies do not perform a false attack.

For jumps, h(u)=4Hu(1−u), with H=1.45 for hopper and H=1.10 for the heavier felt boss. Normal duration remains 0.95 s, chilled duration 1.70 s. Rendering and death events share h and its derivative v=4H(1−2u)/T. Normal initial vertical speeds are 6.11 and 4.63 world units/s; the equivalent accelerations are 12.85 and 9.75 units/s². These are stylized trajectories with unchanged horizontal destinations and attack timing.

Death preserves the current motion. Coal sheds dark chunks, stone tips with its shield and heavy fragments, ceramic breaks into thin curved pieces, felt loosens windings and lands in soft loops. Debris uses a bounded pool and material-specific bounce/friction. Dynamic damage, drops and kill rewards remain authoritative and occur once.

## Light

One warm key, a soft cool rim and low ambient fill reveal material volume. A soft contact shadow anchors feet; airborne shadows stay on the rug. Eye light is localized emission, not an extra shadow-casting light per eye. Ceramic has a broad muted glaze highlight, stone/coal are rough, felt scatters light across yarn. Use the same setup in the capture and live arena.

## Validation

Headless checks passed: simulation 248, boss rules 83, spirits 25, runestones 24, death motion 270, presentation 19, debris 8 and enemy rigs 59. The rig suite includes material response, true-displacement gait, momentum retention, cleanup and propagation of fire/frost to the actual illustrated body material.

After visual rejection of the procedural wrapping, felt and stone use detailed 2.5D reference body layers with separate live face/feet/shield components. See `enemy-reference-layers.md` for provenance and limitations. Physical collision, grounded shadows, gait, jumps and death momentum still run in the 3D scene; the body artwork itself does not offer arbitrary-view 3D rotation. At death the felt body transitions to loosened 3D yarn loops.

Capture scripts cover the four material families, burning and frost phases, a 2.5-second target marker and a narrow gameplay viewport. Fixed-FPS capture is visual evidence, not a device-performance benchmark.


Final visual evidence: `work/enemy-motion/enemy-animations.mp4` (7.5 seconds), `felt-boss-v2.mp4` (6 seconds: calm, burning, frost), `boss-intent.mp4` (8.5 seconds) and `boss-narrow-060.png` / `boss-narrow-175.png` (target marker appears and then disappears). All four final graphical capture logs contained no script or shader errors. A total of 736 assertions passed in the listed headless suites. `git diff --check` passed.
