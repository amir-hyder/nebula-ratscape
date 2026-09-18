# NAVI brand

The mark is the navigation chevron the child already sees on the watch map, so the
logo and the product are the same object.

## Colours

| Token | Hex | Use |
| --- | --- | --- |
| Teal dark | `#0F766E` | Logo ground, headers, primary buttons |
| Teal | `#10A3A0` | Accents, bus legs on maps |
| Mint | `#F0FDFA` | Page background, reversed logo ground |
| Ink | `#0C111D` | Wordmark and body text |
| Red | `#C83F43` | Help requests and critical alerts only |
| Amber | `#B66711` | Reroutes and delays only |

## Type

Wordmark is **Outfit 800**, letter-spacing `-0.035em`. Body text uses the app's
existing stack. Red and amber never carry meaning on their own; every state also
has a word or an icon, since roughly one boy in twelve cannot separate them.

## Files

| File | Use |
| --- | --- |
| `navi-mark.svg` | Primary, white chevron on teal |
| `navi-mark-light.svg` | On dark or teal backgrounds |
| `navi-mark-mono.svg` | One-colour print |
| `navi-maskable.svg` | Android maskable, chevron inside the 80% safe area |
| `favicon-32.png` | Browser tab |
| `Icon-192.png`, `Icon-512.png` | Web app manifest |
| `Icon-maskable-192.png`, `Icon-maskable-512.png` | Maskable manifest entries |

The PNGs are rendered from the SVGs. Re-export rather than editing them.

## Rules

Clear space on every side is a quarter of the mark's width. Corner radius is 27%
of the icon width, so it survives being masked to a circle. Never place the solid
teal mark on a teal ground; use the light version.
