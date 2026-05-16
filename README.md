# Distortionz Weed Farm

> Premium grow-to-street weed pipeline for Qbox/FiveM — harvest a field for nuggets, roll them into joints (smoke to cut stress), or deal nuggets to street NPCs for dirty money. Feeds the Distortionz CAD dispatch hub.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_WeedFarm?style=flat-square&color=d4aa62&label=version)

---

## Overview

A self-contained, server-authoritative weed loop:

```
grow field → harvest → weed_nugget → /rolljoint → dz_joint → smoke → stress ↓
                              └────────→ /sellweed → street NPCs → black_money
```

Smoking fires the stock `hud:server:RelieveStress` event (the same path
`qbx_consumables` uses), so it works with the base HUD with zero wiring.

## Features

- **Grow field** — config-placed ripe plant props, `ox_target` harvest with
  a progress bar, randomized nugget yield, server-side per-plant regrow
  cooldown with automatic prop swap (ground-snapped + sanity-clamped)
- **Rolling** — `/rolljoint` turns nuggets (+ optional paper item) into a
  branded `dz_joint`, with validation and rollback
- **Smoking** — using `dz_joint` plays the stock `scully_emotemenu`
  **`joint`** emote (falls back to a plain anim if scully isn't running)
  and relieves stress over configurable cycles via the canonical HUD event
- **Street dealing** — `/sellweed` toggles cornersell-style mode: nearest
  valid pedestrian, `[E]` to offer, server-authoritative accept/refuse,
  price + payout, two-sided deal animation with a hand-off bag prop
  (`Config.Sell.bag`), refusal flee, per-ped and per-player cooldowns
- **Police heat** — configurable per-deal and on-snitch chance, delayed
  dispatch with a flashing blip to police jobs
- **CAD hub feed** — successful heat also surfaces as a live call in
  `distortionz_cad` (guarded; no-op if the CAD isn't running)
- Distortionz notify wrapper + GitHub version checker

## Custom items

Two custom `ox_inventory` items (paste-in snippet:
[`_items_for_ox_inventory.lua`](_items_for_ox_inventory.lua)). `black_money`
is reused from the existing stack and is **not** redefined here.

```lua
['weed_nugget'] = {
    label = 'Weed Nugget',
    weight = 8,
    stack = true,
    close = true,
    description = 'A dense nugget of fresh-harvested bud.',
    client = { image = 'weed_nugget.png' },
},

['dz_joint'] = {
    label = 'Joint',
    weight = 3,
    stack = true,
    close = true,
    description = 'Rolled and ready. Takes the edge off.',
    client = { image = 'dz_joint.png' },
},
```

- `dz_joint` is made **useable by this resource** via
  `qbx_core:CreateUseableItem` — do **not** add an ox client/server `use`
  handler for it in `items.lua`.
- Item images go in `ox_inventory/web/images/` as `weed_nugget.png` and
  `dz_joint.png`.
- Item names are configurable in `config.lua` → `Config.Items`.

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player/job data, useable-item registration |
| `ox_lib` | yes | Callbacks, progress bar, text UI, notify fallback |
| `ox_target` | yes | Plant harvest interaction |
| `ox_inventory` | yes | `weed_nugget`, `dz_joint`, `black_money` |
| `scully_emotemenu` | optional | `joint` smoke emote (anim fallback if absent) |
| `distortionz_notify` | optional | Branded notifications |
| `distortionz_cad` | optional | Live dispatch call on heat |

## Installation

1. Add the items from [`_items_for_ox_inventory.lua`](_items_for_ox_inventory.lua)
   to `ox_inventory/data/items.lua` (inside the returned table), and drop
   `weed_nugget.png` / `dz_joint.png` into `ox_inventory/web/images/`.
2. Add to `server.cfg`:

```cfg
ensure ox_lib
ensure qbx_core
ensure ox_target
ensure ox_inventory
ensure distortionz_weedfarm
```

3. Set your real field coordinates in `Config.Field.plants`
   (the shipped coords are placeholders).

## Commands

| Command | Action |
|---|---|
| `/rolljoint` | Roll `Config.Roll.nuggetsPerJoint` nuggets into a joint |
| `/sellweed` | Toggle street-dealing mode (then `[E]` near a pedestrian) |

## Configuration

See [`config.lua`](config.lua): item names, grow field + yield + regrow,
rolling recipe, street-deal pricing/odds/cooldowns + hand-off bag prop,
police heat, and joint smoke emote / stress-relief tuning.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
