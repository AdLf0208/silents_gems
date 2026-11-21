# Silent's Gems — validation record (slices 1-3, campaign pin `0a875da`)

Port: [`ports/silentgems`](.) — Silent's Gems **5.2.0** source, packaged as **5.2.1** (MIT);
ATM10 ships 1.21.1-5.1.3 with the same 21 gem ids and the same lamp ids (see `notes.md` "Scope and
version": the package says 5.2.1 because that is the source it was built from plus this slice).
Pin: Horizon `0a875da91dbb0fdcb7ba8c42c11341aa229af51a` / horizon-mixins
`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`; Minecraft 26.3 prepared resources; `api = "0.2"`,
flat SDK package.

The retired `.hnmod` bundle (5.2.0) and its run logs are under
`ports/_shared/evidence/silentgems/retired-5.2.0/`; this record is the SDK package only.

All commands ran in this port through `ports/tools/build-slot.sh` (`BUILD_LOCAL=1`,
`CARGO_INCREMENTAL=0`; no bare cargo outside a lease, no `--target-dir`). Evidence:
`ports/_shared/evidence/silentgems/` (ladder) and `ports/_shared/evidence/silentgems-e2e/` (in-game);
every ladder log names the package's size and SHA-256 in its first line.

## Runtime and glue (SDK crate)

| Check | Command | Result |
|---|---|---|
| fmt | `cargo fmt --check` | `FMT_EXIT:0` (`sdk-fmt.log`) |
| clippy | `cargo clippy --all-targets -- -D warnings` | exit 0, **0 warnings** (`sdk-clippy.log`) |
| tests | `cargo test` | `16 passed; 0 failed` (`sdk-test.log`) |
| red first | the same before the lamp rule existed | `10 passed; 6 failed` — `not yet implemented: the lamp id table`, `the lamp state table` (`sdk-test-red.log`) |

## The package (delivered at the port root)

| Check | Command | Result |
|---|---|---|
| build 1 | `rm -f Cargo.lock && cargo horizon-mod build` | `target/horizon-mod/silentgems.hmod` (`sdk-build.log`) |
| build 2 | the same again, `rm -f Cargo.lock` first | `cmp` identical, same SHA-256 (`sdk-build-second.log`) |
| check | `cargo horizon-mod check silentgems.hmod` | `silentgems 5.2.1 (native-mod, format native-1/0a875da…/e59da90…, for 26.3)`, exit 0 (`sdk-check.log`) |
| fits the pin | `cargo horizon-mod fits silentgems.hmod --build 0a875da` | `0a875da  made for`, exit 0 (`sdk-fits.log`) |
| fits another build | `cargo horizon-mod fits silentgems.hmod --build 0b14f8a` | `0b14f8a  fits`, exit 0 (`sdk-fits-other.log`) |
| packed `Cargo.lock` | `unzip -l` | none (`sdk-entries.log`) |

Delivered [`silentgems.hmod`](silentgems.hmod): **464,271 bytes**, SHA-256
`c500c8212d540cf2642f633b3fcc7a37ddc838ad8389b2a0aae30fcd691e4c42`, **1,446 entries**
(`sdk-entries.log`, `sdk-sha256.txt`); manifest version **5.2.1**.

## In-game runs (launcher-built game at the pin)

```sh
ports/tools/launcher-game.sh build silentgems
eval "$(ports/tools/launcher-game.sh env silentgems)"
ports/tools/build-slot.sh run --job W1-silentgems-e2e --port ports/silentgems \
    --step e2e -- bash ports/silentgems/tools/e2e.sh
```

| Run | Command | Result |
|---|---|---|
| default | `tools/e2e.sh` | **PASS + `EXIT:0`** — `e2e-launcher.log` |
| control | `CONTROL=1 tools/e2e.sh` (same Nightly, no package) | **FAIL + `EXIT:1`** as required — `e2e-control.log` |
| negative | `NEGATIVE=1 tools/e2e.sh` | **FAIL + `EXIT:1`** as required — `e2e-negative.log` |
| selftest | `SELFTEST=1 tools/e2e.sh` | **FAIL + `EXIT:1`** as required — `e2e-selftest.log` |

`python3 ports/tools/check-e2e-logs.py silentgems-e2e --strict` → exit 0:
`logs=4 ok=4 missing-exit=0 bad-exit=0`.

Default run: 21 gems, 21 storage blocks and 84 ores still give; 21/21 storage states bind and the
block tags match (`#minecraft:mineable/pickaxe`, `#c:storage_blocks[/<gem>]`, `#silentgems:ores/<gem>`,
`#c:ores/<gem>`, `#minecraft:needs_iron_tool`); the tab lists every gem, block and both lamp items;
42/42 resting lamp states bind and 42/42 hand-set `_on`/`_inverted` blocks revert to the unpowered
form; 42/42 lamp items give while the two item-less states are refused; `ruby_lamp` (light 0) →
`ruby_lamp_on` (light `f`) beside a redstone block → back when it is removed;
`opal_lamp_inverted_on` (15) → `opal_lamp_inverted` (0) while powered → back; `topaz_lamp` placed
beside a signal reads `topaz_lamp_on`; vanilla `minecraft:redstone_lamp` goes `lit=true`/`lit=false`
under the same signal; `ruby_lamp_on` drops one `ruby_lamp`, `opal_lamp_inverted_on` drops one of
itself and vanilla drops itself; the shaped and shapeless lamp recipes craft and consume their
ingredients with both wrong-ingredient controls empty; bogus ids and the deferred
`silentgems:ruby_teleporter` are refused.

**Worldgen gap (measured, asserted).** At `0a875da` a package's `worldgen/configured_feature/` files
do not reach the feature registry: `/place feature silentgems:overworld/ruby_ore` answers
`Can't find element … in registry 'minecraft:worldgen/feature'`, the overlay's `features.json` is
linked unchanged, and the merged placed features are skipped with `unknown feature reference`. A
minimal one-feature probe package fails the same way, so it is the pin. The e2e asserts the gap (it
will fail when the pin starts merging), `notes.md` records `blocked(configured-feature-not-registered)`
for the three worldgen families, and the measurement is in `worldgen-gap.md`.

Control: the unmodded Nightly reads `minecraft:air` where the package places `silentgems:ruby_lamp`,
so the modded run is not vacuous.

## Disk

The staged cargo target stayed in the slot cache and the lease removed the port's cache symlinks. The
port keeps its sources, `assets/`, `data/` and the delivered `silentgems.hmod`; the retired 5.2.0
bundle lives under `ports/_shared/evidence/silentgems/retired-5.2.0/`.
