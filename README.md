# Silent's Gems — a Horizon port

**Silent's Gems** is a Minecraft mod. A Minecraft mod mostly about tools and colorful building blocks. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [SilentChaos512/SilentGems](https://github.com/SilentChaos512/SilentGems) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Silent's Gems ([source](https://github.com/SilentChaos512/SilentGems)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `silentgems.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

- **This port is version 5.2.0, not 5.1.3.** The mixin bundle
- `CHANGELOG.md:6` (`26.2-5.2.0`) says only "Ported to NeoForge 26.2, Silent
- `CHANGELOG.md:38` says the last five gems (`garnet`, `aquamarine`,
- Both versions therefore declare the same **21 gems**; the 26.2 source is
- `silentgems:<name>` — a plain item with the enum's rarity, no use/tick/
- `silentgems:<name>_block` — a plain `Block` with upstream's
- a shaped 3×3 recipe of `#c:gems/<name>` → one block, and a shapeless recipe
- block tags `c:storage_blocks/<name>` and `c:storage_blocks`, and

## Not yet ported

- **Slices 1-2 only.** Terrain/glowrose plants, tool/armour sets, lamps,
- **Ore loot subset.** The pin has no `match_tool`, `apply_bonus` or
- **Ore experience** comes from the template (lapis: 2-5); upstream's ore used
- **`%s` name templates expanded.** Rendered names match upstream, but the
- **Creative tab placement and contents.** Upstream's code tab lists every
- **Rarity is the only gem item effect.** There is no tooltip showing the
- **No `minecraft:beacon_payment_items` gameplay test.** The tag is written
- **`horizon-mod check` does not parse recipes/loot/worldgen.** It validates

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `silentgems.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Silent's Gems was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/SilentChaos512/SilentGems

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run silentgems` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/silentgems/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
