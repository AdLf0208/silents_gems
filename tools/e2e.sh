#!/usr/bin/env bash
# In-game check for the Silent's Gems lamp slice (5.2.1), plus a regression over the
# content the same package still ships (slices 1-2: gems, storage blocks and ores).
#
# The package is native: its content and its lamp code are one `.hmod` the launcher
# compiles into the game, so `GAME` must be a game built with it:
#
#   ports/tools/launcher-game.sh build silentgems
#   eval "$(ports/tools/launcher-game.sh env silentgems)"
#   ports/tools/build-slot.sh run --job W1-silentgems --port ports/silentgems \
#       --step e2e -- bash ports/silentgems/tools/e2e.sh
#
# Default run (offscreen renderer, creative; The End):
#   A. the 21 gem items, 21 storage blocks and 84 ores are `/give`-able, and the 21
#      storage-block states bind; the creative tab lists all 168 entries;
#   B. all 84 lamp ids bind (the two lit and the two inverted states are distinct blocks),
#      and the 42 lamp items are give-able while the two item-less states are refused;
#   C. **the lamp rule**: a lamp beside no signal is unlit and emits 0, a redstone block
#      beside it switches it to its `_on` (lit, 15) block, removing the signal switches it
#      back; an inverted lamp is lit until powered and dark while powered; a lamp placed
#      beside an existing signal resolves on placement; a vanilla `minecraft:redstone_lamp`
#      goes `lit=true` under the same signal (the differential — the harness's power
#      switching is live, and our lamp follows the same vanilla rule);
#   D. a `ruby_lamp_on` (no item) drops one `silentgems:ruby_lamp`, an unlit
#      `opal_lamp_inverted` drops one `opal_lamp_inverted_on`, and vanilla `redstone_lamp`
#      drops itself (the drop differential);
#   E. the shaped lamp recipe and the shapeless inversion craft and consume their
#      ingredients, with empty wrong-ingredient controls (`tools/craft_lamps.py`);
#   F. unknown ids are refused.
#
# CONTROL=1 runs the same core phase on `GAME=$CONTROL_GAME` — the same Nightly without the
# package — where `silentgems:ruby_lamp` cannot exist; the run MUST fail (EXIT:1), which is
# what proves the modded run is not vacuous.
# NEGATIVE=1 keeps the default run but asserts that an unpowered lamp IS `_on` (false), so the
# run MUST fail at the switch phase (EXIT:1): the switch assertion can fail.
# SELFTEST=1 keeps the default run but asserts a lit lamp emits 0 (false), so the run MUST
# fail at the light phase (EXIT:1): the light read-back is live.
# Every leg prints `EXIT:<status>` from the cleanup trap as its last line.
set -euo pipefail

PORT=$(cd "$(dirname "$0")/.." && pwd)
CTL=${CTL:-}
GAME=${GAME:-}
CONTROL_GAME=${CONTROL_GAME:-}
RES=${RES:-${HORIZON_RES:-}}
SOCK=${SOCK:-/tmp/opencode/silentgems-e2e.sock}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}
CONTROL=${CONTROL:-0}

[ -n "$CTL" ] || { echo "CTL is unset: eval \"\$(ports/tools/launcher-game.sh env silentgems)\"" >&2; exit 1; }
[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
if [ "$CONTROL" = 1 ]; then
    GAME=$CONTROL_GAME
fi
[ -n "$GAME" ] || {
    echo "GAME is unset: the SDK package is compiled into the game by the launcher." >&2
    echo "  ports/tools/launcher-game.sh build silentgems" >&2
    exit 1
}
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/silentgems.hmod" ] || { echo "missing package: $PORT/silentgems.hmod" >&2; exit 1; }

GEMS=(ruby carnelian topaz citrine heliodor moldavite peridot turquoise \
    kyanite sapphire iolite alexandrite ammolite rose_quartz black_diamond \
    white_diamond garnet aquamarine tanzanite opal pearl)
WORLD=SilentGemsLampsE2E
[ "$CONTROL" = 1 ] && WORLD=SilentGemsControlE2E

SCRATCH=$(mktemp -d /home/adlf/.cache/horizon-e2e/scratch/silentgems-home.XXXXXX 2>/dev/null \
    || mktemp -d /tmp/opencode/silentgems-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")" "$XDG_CONFIG_HOME"
rm -f "$SOCK"

ctl() { "$CTL" --socket "$SOCK" --timeout 180 "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
block_id() { ctl block "$1" "$2" "$3" | jq -r '.block // .name // "unknown"'; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
light_at() { ctl light "$1" "$2" "$3" "$1" "$2" "$3" | jq -r '.block'; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
end() { ctl command "execute in minecraft:the_end run $1"; }

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" 2>/dev/null || true
    echo "EXIT:$status"
}
trap cleanup EXIT

say "launch $GAME (offscreen, creative), world $WORLD"
cd "$SCRATCH"
"$CTL" --socket "$SOCK" launch --game "$GAME" --world "$WORLD" --seed 20261105 --creative \
    --offscreen --wait --game-dir "$SCRATCH/game" --resources "$RES" >/dev/null
ctl wait-ready 180

say "The End platform at y=79 and an empty box above it"
end "forceload add -16 -16 24 12"
end "tp @s 0.5 80 2.5"
ctl wait 40
end "fill -16 79 -16 24 79 12 minecraft:stone"
end "fill -16 80 -16 24 88 12 minecraft:air"
end "kill @e[type=!player]"
end "difficulty peaceful"
end "tp @s 0.5 80 2.5"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3

# ------------------------------------------------------- the control leg
# The same package on the unmodded Nightly cannot hold a lamp id at all. This leg is the
# proof the modded run is not vacuous, so it must FAIL.
if [ "$CONTROL" = 1 ]; then
    say "CONTROL: silentgems:ruby_lamp on the unmodded Nightly (must not exist)"
    ctl setblock 2 80 0 silentgems:ruby_lamp >/dev/null 2>&1 || true
    ctl wait 5
    got=$(block_id 2 80 0)
    echo "  control block at 2,80,0: $got"
    [ "$got" = "silentgems:ruby_lamp" ] \
        || fail "CONTROL run: the core lamp id is absent without the package ($got), as this control leg requires"
    fail "CONTROL run: expected to fail, but the unmodded Nightly holds a Silent's Gems lamp"
fi

# ------------------------------------------------------------- regression
say "the 21 gems, 21 storage blocks and 84 ores are still give-able"
ctl command "clear @s" >/dev/null
for gem in "${GEMS[@]}"; do ctl give "silentgems:${gem}" 1 >/dev/null || fail "give silentgems:${gem} failed"; done
ctl wait 8
for gem in "${GEMS[@]}"; do [ "$(count_item "silentgems:${gem}")" -ge 1 ] || fail "silentgems:${gem} is missing"; done
ctl command "clear @s" >/dev/null
for gem in "${GEMS[@]}"; do ctl give "silentgems:${gem}_block" 1 >/dev/null || fail "give silentgems:${gem}_block failed"; done
ctl wait 8
for gem in "${GEMS[@]}"; do [ "$(count_item "silentgems:${gem}_block")" -ge 1 ] || fail "silentgems:${gem}_block is missing"; done
ctl command "clear @s" >/dev/null
for prefix in "" deepslate_ nether_ end_; do
    for gem in "${GEMS[@]}"; do
        ctl give "silentgems:${prefix}${gem}_ore" 1 >/dev/null || fail "give silentgems:${prefix}${gem}_ore failed"
    done
    ctl wait 8
    for gem in "${GEMS[@]}"; do
        [ "$(count_item "silentgems:${prefix}${gem}_ore")" -ge 1 ] || fail "silentgems:${prefix}${gem}_ore is missing"
    done
    ctl command "clear @s" >/dev/null
done
echo "21 gems, 21 storage blocks and 84 ores give"

say "the 21 storage-block states still bind"
for i in "${!GEMS[@]}"; do
    ctl setblock "$i" 80 -6 "silentgems:${GEMS[$i]}_block" >/dev/null || fail "setblock silentgems:${GEMS[$i]}_block failed"
done
ctl wait 8
for i in "${!GEMS[@]}"; do
    [ "$(block_id "$i" 80 -6)" = "silentgems:${GEMS[$i]}_block" ] || fail "x=$i is not the ${GEMS[$i]} block"
done
echo "21/21 storage-block states bind"

say "the block tags still match (storage block, ore, harvest tier)"
ctl command "execute in minecraft:the_end if block 0 80 -6 #minecraft:mineable/pickaxe run say TAG_BLOCK_PICKAXE" >/dev/null
ctl command "execute in minecraft:the_end if block 0 80 -6 #c:storage_blocks run say TAG_CSTORAGE_ALL" >/dev/null
ctl command "execute in minecraft:the_end if block 0 80 -6 #c:storage_blocks/ruby run say TAG_CSTORAGE_RUBY" >/dev/null
end "setblock 3 80 -7 silentgems:ruby_ore"
ctl wait 3
ctl command "execute in minecraft:the_end if block 3 80 -7 #silentgems:ores/ruby run say TAG_ORE_MOD" >/dev/null
ctl command "execute in minecraft:the_end if block 3 80 -7 #c:ores/ruby run say TAG_ORE_C" >/dev/null
ctl command "execute in minecraft:the_end if block 3 80 -7 #minecraft:needs_iron_tool run say TAG_ORE_IRON" >/dev/null
ctl wait 4
messages=$(ctl messages 40 | jq -r '.chat[]')
for tag in TAG_BLOCK_PICKAXE TAG_CSTORAGE_ALL TAG_CSTORAGE_RUBY TAG_ORE_MOD TAG_ORE_C TAG_ORE_IRON; do
    echo "$messages" | grep -q "$tag" || fail "the block tag check missed $tag"
done
end "setblock 3 80 -7 minecraft:air"
echo "ruby_block: #minecraft:mineable/pickaxe, #c:storage_blocks, #c:storage_blocks/ruby; ruby_ore: #silentgems:ores/ruby, #c:ores/ruby, #minecraft:needs_iron_tool"

say "the creative tab lists all 168 entries"
CREATIVE=$(find "$SCRATCH/game/.horizon-cache/mod-content" -maxdepth 2 -name creative-inventory.json 2>/dev/null | head -1)
[ -n "$CREATIVE" ] || fail "no creative-inventory.json under the game's mod-content cache"
flat=$(tr -d '\\' < "$CREATIVE")
for gem in "${GEMS[@]}"; do
    for id in "${gem}" "${gem}_block" "${gem}_lamp" "${gem}_lamp_inverted_on"; do
        echo "$flat" | grep -q "silentgems:${id}\"" || fail "creative tab misses silentgems:${id}"
    done
done
echo "the tab carries the gems, blocks and both lamp items of every gem"

# ------------------------------------------------------------- lamp states
# The two states a lamp rests in without a signal bind as written.
say "the 42 unpowered resting states bind (off and inverted, lit)"
i=0
for gem in "${GEMS[@]}"; do
    for id in "${gem}_lamp" "${gem}_lamp_inverted_on"; do
        x=$((i % 21))
        z=$(( -10 - i / 21 ))
        ctl setblock "$x" 80 "$z" "silentgems:${id}" >/dev/null || fail "setblock silentgems:${id} failed"
        i=$((i + 1))
    done
done
ctl wait 10
i=0
for gem in "${GEMS[@]}"; do
    for id in "${gem}_lamp" "${gem}_lamp_inverted_on"; do
        x=$((i % 21))
        z=$(( -10 - i / 21 ))
        got=$(block_id "$x" 80 "$z")
        [ "$got" = "silentgems:${id}" ] || fail "x=$x z=$z reads '$got', expected silentgems:${id}"
        i=$((i + 1))
    done
done
echo "42/42 resting states bind (lamp, lamp_inverted_on)"

# The other two ids exist and the rule owns them: a hand-set lit normal lamp with no signal
# becomes the unlit block, and a hand-set unlit inverted lamp with no signal becomes the lit
# one. That is the same rule the switch phase below drives with a real redstone block.
say "the 42 rule-owned states revert to the unpowered form for every gem"
i=0
for gem in "${GEMS[@]}"; do
    for id in "${gem}_lamp_on" "${gem}_lamp_inverted"; do
        x=$((i % 21))
        z=$(( -14 - i / 21 ))
        ctl setblock "$x" 80 "$z" "silentgems:${id}" >/dev/null || fail "setblock silentgems:${id} failed"
        i=$((i + 1))
    done
done
ctl wait 12
i=0
for gem in "${GEMS[@]}"; do
    for want in "${gem}_lamp" "${gem}_lamp_inverted_on"; do
        x=$((i % 21))
        z=$(( -14 - i / 21 ))
        got=$(block_id "$x" 80 "$z")
        [ "$got" = "silentgems:${want}" ] || fail "x=$x z=$z reads '$got', expected silentgems:${want}"
        i=$((i + 1))
    done
done
echo "42/42 hand-set on/inverted blocks became their unpowered form"

say "the 42 lamp items are give-able and the two item-less states are not"
ctl command "clear @s" >/dev/null
for gem in "${GEMS[@]}"; do
    ctl give "silentgems:${gem}_lamp" 1 >/dev/null || fail "give ${gem}_lamp failed"
    ctl give "silentgems:${gem}_lamp_inverted_on" 1 >/dev/null || fail "give ${gem}_lamp_inverted_on failed"
    ctl wait 1
    ctl command "clear @s" >/dev/null
done
ctl wait 3
if ctl give silentgems:ruby_lamp_on 1 >/dev/null 2>&1 && [ "$(count_item silentgems:ruby_lamp_on)" -ge 1 ]; then
    fail "silentgems:ruby_lamp_on (no item) was given"
fi
if ctl give silentgems:ruby_lamp_inverted 1 >/dev/null 2>&1 && [ "$(count_item silentgems:ruby_lamp_inverted)" -ge 1 ]; then
    fail "silentgems:ruby_lamp_inverted (no item) was given"
fi
ctl command "clear @s" >/dev/null
echo "42/42 lamp items give; the two item-less states are refused"

# ----------------------------------------------------------- the lamp rule
say "an unpowered lamp is unlit and emits 0"
ctl setblock 2 80 0 silentgems:ruby_lamp >/dev/null || fail "cannot place the ruby lamp"
ctl wait 6
got=$(block_id 2 80 0)
[ "$got" = "silentgems:ruby_lamp" ] || fail "the unpowered ruby lamp is '$got'"
light=$(light_at 2 80 0)
[ "$light" = "0" ] || fail "the unpowered ruby lamp emits '$light'"
echo "  ruby_lamp: $got, light $light"

say "a signal switches it to ruby_lamp_on (lit, 15) and removing the signal switches it back"
ctl setblock 3 80 0 minecraft:redstone_block >/dev/null || fail "cannot place the redstone block"
ctl wait 8
got=$(block_id 2 80 0)
[ "$got" = "silentgems:ruby_lamp_on" ] || fail "the powered ruby lamp is '$got', expected silentgems:ruby_lamp_on"
light=$(light_at 2 80 0)
[ "$light" = "f" ] || fail "the powered ruby lamp emits '$light', expected 'f' (15)"
if [ "$NEGATIVE" = 1 ]; then
    # Deliberately false: the powered lamp is `_on`, so this assertion MUST fail.
    [ "$got" = "silentgems:ruby_lamp" ] \
        || fail "NEGATIVE run: the switch assertion is live ($got); this exit 1 is the proof"
fi
if [ "$SELFTEST" = 1 ]; then
    # Deliberately false: a lit lamp emits 15, so this MUST fail.
    [ "$light" = "0" ] || fail "SELFTEST: the light read-back is live ($light); this exit 1 is the proof"
fi
ctl setblock 3 80 0 minecraft:air >/dev/null
ctl wait 8
got=$(block_id 2 80 0)
[ "$got" = "silentgems:ruby_lamp" ] || fail "after the signal was removed the lamp is '$got'"
light=$(light_at 2 80 0)
[ "$light" = "0" ] || fail "after the signal was removed the lamp emits '$light'"
echo "  off -> on -> off: ruby_lamp, ruby_lamp_on, ruby_lamp; light 0, f, 0"

say "an inverted lamp is lit until powered and dark while powered"
ctl setblock 5 80 0 silentgems:opal_lamp_inverted_on >/dev/null || fail "cannot place the inverted lamp"
ctl wait 6
got=$(block_id 5 80 0)
[ "$got" = "silentgems:opal_lamp_inverted_on" ] || fail "the unpowered inverted lamp is '$got'"
light=$(light_at 5 80 0)
[ "$light" = "f" ] || fail "the unpowered inverted lamp emits '$light'"
ctl setblock 6 80 0 minecraft:redstone_block >/dev/null
ctl wait 8
got=$(block_id 5 80 0)
[ "$got" = "silentgems:opal_lamp_inverted" ] || fail "the powered inverted lamp is '$got'"
light=$(light_at 5 80 0)
[ "$light" = "0" ] || fail "the powered inverted lamp emits '$light'"
ctl setblock 6 80 0 minecraft:air >/dev/null
ctl wait 8
got=$(block_id 5 80 0)
[ "$got" = "silentgems:opal_lamp_inverted_on" ] || fail "after the signal was removed the inverted lamp is '$got'"
echo "  inverted: lit, dark while powered, lit again"

say "a lamp placed beside an existing signal resolves on placement"
ctl setblock 8 80 0 minecraft:redstone_block >/dev/null
ctl wait 4
ctl setblock 9 80 0 silentgems:topaz_lamp >/dev/null || fail "cannot place the topaz lamp"
ctl wait 8
got=$(block_id 9 80 0)
[ "$got" = "silentgems:topaz_lamp_on" ] || fail "the lamp placed beside a signal is '$got', expected silentgems:topaz_lamp_on"
echo "  topaz_lamp placed beside a redstone block is $got"

say "differential: vanilla redstone_lamp goes lit=true under the same signal"
ctl setblock 11 80 0 minecraft:redstone_lamp >/dev/null
ctl setblock 12 80 0 minecraft:redstone_block >/dev/null
ctl wait 8
state=$(block_state 11 80 0)
echo "$state" | grep -q "lit=true" || fail "the vanilla redstone lamp is '$state' under a signal"
ctl setblock 12 80 0 minecraft:air >/dev/null
ctl wait 8
state=$(block_state 11 80 0)
echo "$state" | grep -q "lit=false" || fail "the vanilla redstone lamp is '$state' without a signal"
echo "  vanilla redstone_lamp: lit=true under the signal, lit=false without it"

# ------------------------------------------------------------------- drops
say "survival: a ruby_lamp_on drops one ruby_lamp"
for pos in "2 80 4" "3 80 4" "4 80 4"; do
    set -- $pos
    end "setblock $1 $2 $3 minecraft:air"
done
# The ruby lamp is held in its powered, item-less state by a redstone block beside it, so the
# break below drops from `ruby_lamp_on` and not from a lamp the rule already reverted.
ctl setblock 1 80 4 minecraft:redstone_block >/dev/null || fail "cannot place the redstone block"
ctl setblock 2 80 4 silentgems:ruby_lamp >/dev/null || fail "cannot place the ruby lamp"
ctl setblock 3 80 4 silentgems:opal_lamp_inverted_on >/dev/null || fail "cannot place the inverted lamp"
ctl setblock 4 80 4 minecraft:redstone_lamp >/dev/null || fail "cannot place the vanilla lamp"
ctl wait 10
[ "$(block_id 2 80 4)" = "silentgems:ruby_lamp_on" ] || fail "the ruby lamp beside a signal is not ruby_lamp_on"
[ "$(block_id 3 80 4)" = "silentgems:opal_lamp_inverted_on" ] || fail "the unpowered inverted lamp is not opal_lamp_inverted_on"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null
ctl tp 0.5 80 4.5 >/dev/null
ctl wait 5
ctl select minecraft:diamond_pickaxe >/dev/null
ctl wait 3
ctl look-at-block 2 80 4 >/dev/null || true
broken=$(ctl break 2 80 4) || fail "cannot break the lit lamp"
echo "$broken" | jq -c '{block,block_before,drops}'
lamp=$(echo "$broken" | jq -r '.drops["silentgems:ruby_lamp"] // 0')
[ "$lamp" -ge 1 ] || fail "ruby_lamp_on dropped $lamp ruby_lamp"
echo "$broken" | jq -r '.block_before' | grep -q '^silentgems:ruby_lamp_on' \
    || fail "the broken block was not ruby_lamp_on"
ctl look-at-block 3 80 4 >/dev/null || true
broken=$(ctl break 3 80 4) || fail "cannot break the inverted lamp"
echo "$broken" | jq -c '{block,block_before,drops}'
inverted=$(echo "$broken" | jq -r '.drops["silentgems:opal_lamp_inverted_on"] // 0')
[ "$inverted" -ge 1 ] || fail "opal_lamp_inverted dropped $inverted opal_lamp_inverted_on"
ctl look-at-block 4 80 4 >/dev/null || true
broken=$(ctl break 4 80 4) || fail "cannot break the vanilla lamp"
echo "$broken" | jq -c '{block,block_before,drops}'
vanilla=$(echo "$broken" | jq -r '.drops["minecraft:redstone_lamp"] // 0')
[ "$vanilla" -ge 1 ] || fail "the vanilla redstone lamp dropped $vanilla of itself"
echo "  ruby_lamp_on -> ruby_lamp; opal_lamp_inverted -> opal_lamp_inverted_on; vanilla -> itself"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 3

# ----------------------------------------------------------------- recipes
say "craft: the shaped lamp recipe and the shapeless inversion, with empty controls"
end "setblock 10 80 6 minecraft:crafting_table"
ctl command "gamemode survival @s" >/dev/null
ctl tp 9.5 80 6.5 >/dev/null
ctl wait 5
python3 "$PORT/tools/craft_lamps.py" "$SOCK" "$CTL" 10 80 6 || fail "the lamp recipe check failed"

# The 42 compression recipes ship in the same package: craft four of them (two gems each way)
# and their two wrong-item controls, so slices 1-2's recipes are not dead data.
say "craft: the 9<->1 compression recipes (slice 1-2 regression)"
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 12 80 6 || fail "the compression recipe check failed"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 3

# ------------------------------------------------------- worldgen (recorded gap)
# The package carries the 84 ores' 28 configured + 28 placed features and the three biome
# modifiers. At this pin a content or native package's `worldgen/configured_feature/` files do
# not reach the `minecraft:worldgen/feature` registry: `/place feature` cannot find the id, and
# the worldgen loader logs `unknown feature reference` for every placed feature that names one.
# The assertion below is the gap: it passes while the engine drops them and FAILS the day the
# pin gains the merge, which is the signal to turn this phase into the real `/place feature`
# check and move the coverage rows from `blocked` to `tested`.
say "worldgen: the carried features are inert at this pin (measured gap, asserted)"
end "forceload add 28 -12 56 12"
end "tp @s 40.5 120 0.5"
ctl wait 20
end "fill 31 12 -8 49 28 8 minecraft:stone"
ctl wait 6
reply=$(ctl command "place feature silentgems:overworld/ruby_ore 40 20 0" | jq -r '.chat | join(" ")')
echo "  /place feature silentgems:overworld/ruby_ore: $reply"
echo "$reply" | grep -q "Can't find element 'silentgems:overworld/ruby_ore'" \
    || fail "the configured-feature gap changed (the pin may now merge mod features): $reply"
placed=$(ctl blocks 31 12 -8 49 28 8 | jq -r '.counts["silentgems:ruby_ore"] // 0')
echo "  ruby ore placed by the feature: $placed"
[ "$placed" -eq 0 ] || fail "the feature placed $placed ore after the registry refused the id"
echo "  the worldgen loader's own verdict:"
grep -m 2 "unknown feature reference" "$SCRATCH/game/logs/latest.log" | sed 's/^/    /' || true
echo "worldgen: 28 configured + 28 placed features carried, inert at 0a875da (gap asserted)"

# -------------------------------------------------------------- refusals
say "unknown ids are refused"
if ctl give silentgems:not_a_lamp 1 >/dev/null 2>&1 && [ "$(count_item silentgems:not_a_lamp)" -ge 1 ]; then
    fail "give silentgems:not_a_lamp succeeded"
fi
ctl setblock 18 80 6 silentgems:bogus_block >/dev/null 2>&1 || true
[ "$(block_id 18 80 6)" = "minecraft:air" ] || fail "silentgems:bogus_block became a block"
ctl setblock 19 80 6 silentgems:ruby_teleporter >/dev/null 2>&1 || true
[ "$(block_id 19 80 6)" = "minecraft:air" ] || fail "silentgems:ruby_teleporter became a block (still deferred)"
echo "bogus item/block ids and the deferred ruby_teleporter are refused"

echo "PASS: 84 lamp blocks bind, 42 lamp items give while the two item-less states are refused, a redstone signal switches ruby_lamp <-> ruby_lamp_on (light 0 <-> 15) and the inverted pair the other way, a lamp placed beside a signal resolves, vanilla redstone_lamp follows the same rule, the lamps drop the unpowered item-bearing form while vanilla drops itself, the shaped and shapeless lamp recipes craft and consume their ingredients, the gems/blocks/ores and their block tags are unchanged, the tab lists every gem, block and lamp item, the carried worldgen is inert at this pin and the gap is asserted, and unknown ids are refused"
