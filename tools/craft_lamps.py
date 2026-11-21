#!/usr/bin/env python3
"""Craft the Silent's Gems lamp recipes in a real crafting table.

Called by `tools/e2e.sh` with the open game's control socket. Uses the harness's
crafting grid (`ctl screen`: slots 100-108 row-major, result 200) and asserts:

1. the shaped recipe (`GemsRecipeProvider:105-111`) — 4 redstone dust, 4 glowstone
   dust and one gem in `rgr/gog/rgr` — makes one `silentgems:ruby_lamp`, the stack
   reaches the inventory, and **the nine ingredients are consumed** (redstone,
   glowstone and ruby all read 0 afterwards);
2. a second gem (`opal`) makes its own lamp, so the recipe matches
   `#c:gems/<gem>` rather than one hand-written id;
3. the shapeless inversion (`GemsRecipeProvider:115-117`) — one lamp plus one
   redstone torch — makes `silentgems:ruby_lamp_inverted_on`, and both are
   consumed;
4. the wrong-ingredient controls leave the result empty: eight redstone dust and
   one gem (no glowstone) and one lamp plus a stick.

The table is replaced before every case, so a failed/untaken result cannot leak
into the next grid. Exits 1 with the observed result on the first mismatch.
"""
import json
import subprocess
import sys

# The 3x3 grid, row-major: the shaped lamp recipe's r/g/o positions.
REDSTONE = [100, 102, 106, 108]
GLOWSTONE = [101, 103, 105, 107]
CENTRE = 104
FIRST = [100, 101, 102, 103, 104]


def main():
    sock, ctl, x, y, z = sys.argv[1:6]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def result():
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, targets, right=True):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            if right:
                run("click-slot", str(target), "right")
            else:
                run("click-slot", str(target))
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        # Replace the table so its block entity, and therefore the crafting grid,
        # is fresh for this case.
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        print("debug tp:", run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}"))
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        run("interact", x, y, z)
        wait(5)

    failures = []

    def counts():
        return run("inventory")["counts"]

    def take():
        run("click-slot", "200")
        wait(4)
        run("click-slot", "9")
        wait(3)
        return counts()

    def craft(label, items, placements, want_item, want_count, consumed):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return
        left = take()
        if left.get(want_item, 0) < 1:
            failures.append(f"{label}: {want_item} reached the inventory as 0")
        for item in consumed:
            if left.get(item, 0) != 0:
                failures.append(f"{label}: {item} was not consumed ({left.get(item)})")

    def empty_control(label, items, placements):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']}")

    craft(
        "ruby lamp",
        [("silentgems:ruby", 1), ("minecraft:redstone", 4), ("minecraft:glowstone_dust", 4)],
        [
            ("minecraft:redstone", REDSTONE),
            ("minecraft:glowstone_dust", GLOWSTONE),
            ("silentgems:ruby", [CENTRE]),
        ],
        "silentgems:ruby_lamp",
        1,
        ["minecraft:redstone", "minecraft:glowstone_dust", "silentgems:ruby"],
    )

    craft(
        "opal lamp",
        [("silentgems:opal", 1), ("minecraft:redstone", 4), ("minecraft:glowstone_dust", 4)],
        [
            ("minecraft:redstone", REDSTONE),
            ("minecraft:glowstone_dust", GLOWSTONE),
            ("silentgems:opal", [CENTRE]),
        ],
        "silentgems:opal_lamp",
        1,
        ["silentgems:opal"],
    )

    craft(
        "inverted ruby lamp",
        [("silentgems:ruby_lamp", 1), ("minecraft:redstone_torch", 1)],
        [
            ("silentgems:ruby_lamp", ["100"]),
            ("minecraft:redstone_torch", ["101"]),
        ],
        "silentgems:ruby_lamp_inverted_on",
        1,
        ["silentgems:ruby_lamp", "minecraft:redstone_torch"],
    )

    empty_control(
        "8 redstone + 1 ruby (no glowstone)",
        [("silentgems:ruby", 1), ("minecraft:redstone", 8)],
        [
            ("minecraft:redstone", [100, 101, 102, 103, 105, 106, 107, 108]),
            ("silentgems:ruby", [CENTRE]),
        ],
    )

    empty_control(
        "lamp + stick",
        [("silentgems:ruby_lamp", 1), ("minecraft:stick", 1)],
        [
            ("silentgems:ruby_lamp", ["100"]),
            ("minecraft:stick", ["101"]),
        ],
    )

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "recipe PASS: the shaped lamp recipe and the shapeless inversion craft and consume "
        "their ingredients, a second gem makes its own lamp, and both wrong-ingredient "
        "controls leave the result empty"
    )


if __name__ == "__main__":
    main()
