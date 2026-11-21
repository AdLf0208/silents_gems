#!/usr/bin/env python3
"""Generate the Silent's Gems lamp slice into `data/` and `assets/`.

The lamps are upstream's `GemLampBlock`: one block per (gem, state) pair, named
`<gem>_lamp` + `_inverted` when inverted + `_on` when lit (`Gems.registerLamp`,
`setup/Gems.java:563-576`), with `strength(0.3, 15)` and light 15 while lit. Only the two
states a player can place have an item (`GemLampBlock.State.hasItem` is `lit == inverted`), and
every lamp drops the unpowered, item-bearing form (`GemsLootTableProvider:69-72`).

Everything the port carries is derived from the mod's own files: the textures are the upstream
PNGs, the recipes are `GemsRecipeProvider:105-117` and the names are `en_us.json:12-13`. The
generator refuses to write a file whose source is missing, so a drifted upstream cannot produce a
half slice.

    tools/gen_lamps.py                 # write the files
    tools/gen_lamps.py --check         # exit 1 if a file differs from what would be written
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

PORT = Path(__file__).resolve().parents[1]
UPSTREAM = PORT.parent / "_shared" / "upstream" / "silentgems"
JAR = PORT.parent / "_shared" / "licence-cache" / "silentgems-1.21.1-neoforge-5.1.3.jar"

GEMS = [
    ("ruby", "Ruby"),
    ("carnelian", "Carnelian"),
    ("topaz", "Topaz"),
    ("citrine", "Citrine"),
    ("heliodor", "Heliodor"),
    ("moldavite", "Moldavite"),
    ("peridot", "Peridot"),
    ("turquoise", "Turquoise"),
    ("kyanite", "Kyanite"),
    ("sapphire", "Sapphire"),
    ("iolite", "Iolite"),
    ("alexandrite", "Alexandrite"),
    ("ammolite", "Ammolite"),
    ("rose_quartz", "Rose Quartz"),
    ("black_diamond", "Black Diamond"),
    ("white_diamond", "White Diamond"),
    ("garnet", "Garnet"),
    ("aquamarine", "Aquamarine"),
    ("tanzanite", "Tanzanite"),
    ("opal", "Opal"),
    ("pearl", "Pearl"),
]

# (suffix, lit, inverted, item) — upstream `GemLampBlock.State`, in enum order.
STATES = [
    ("", False, False, True),
    ("_on", True, False, False),
    ("_inverted", False, True, False),
    ("_inverted_on", True, True, True),
]


def text(value: object) -> str:
    return json.dumps(value, indent=2) + "\n"


def block_decl(lit: bool, item: bool) -> str:
    return text(
        {
            "template": "minecraft:stone",
            "properties": {
                "hardness": 0.3,
                "explosion_resistance": 15.0,
                "requires_tool": False,
                "sounds": "minecraft:stone",
                "light": 15 if lit else 0,
            },
            "item": item,
        }
    )


def blockstate(block: str) -> str:
    return text({"variants": {"": {"model": f"silentgems:block/{block}"}}})


def block_model(block: str, texture: str) -> str:
    return text(
        {
            "parent": "minecraft:block/cube_all",
            "textures": {"all": f"silentgems:block/{texture}"},
        }
    )


def item_definition(block: str) -> str:
    return text(
        {"model": {"type": "minecraft:model", "model": f"silentgems:block/{block}"}}
    )


def loot_table(block: str, drop: str) -> str:
    return text(
        {
            "type": "minecraft:block",
            "pools": [
                {
                    "condition": {"type": "minecraft:survives_explosion"},
                    "entries": [{"type": "minecraft:item", "name": f"silentgems:{drop}"}],
                    "rolls": 1,
                }
            ],
            "random_sequence": f"silentgems:blocks/{block}",
        }
    )


def lamp_recipe(gem: str) -> str:
    # GemsRecipeProvider:105-111 — 4 redstone dust, 4 glowstone dust, one gem.
    return text(
        {
            "type": "minecraft:crafting_shaped",
            "category": "building",
            "key": {
                "r": "#c:dusts/redstone",
                "g": "#c:dusts/glowstone",
                "o": f"#c:gems/{gem}",
            },
            "pattern": ["rgr", "gog", "rgr"],
            "result": {"id": f"silentgems:{gem}_lamp", "count": 1},
        }
    )


def inverted_recipe(gem: str) -> str:
    # GemsRecipeProvider:115-117 — one lamp and one redstone torch.
    return text(
        {
            "type": "minecraft:crafting_shapeless",
            "category": "building",
            "ingredients": [
                f"silentgems:{gem}_lamp",
                "minecraft:redstone_torch",
            ],
            "result": {"count": 1, "id": f"silentgems:{gem}_lamp_inverted_on"},
        }
    )


def dust_tag(item: str) -> str:
    # 26.3 ships no `c:` tags, so the port supplies the two the recipe names (as it does for
    # `c:gems`), matching the convention ids upstream's recipe uses.
    return text({"values": [item]})


def texture(gem: str, lit: bool) -> Path:
    name = f"{gem}_lamp{'_on' if lit else ''}.png"
    source = UPSTREAM / "src/main/resources/assets/silentgems/textures/block" / name
    if not source.is_file():
        raise SystemExit(f"missing upstream texture: {source}")
    return source


def files() -> dict[Path, bytes]:
    """Every file this slice owns, by path relative to the port."""
    out: dict[Path, bytes] = {}
    tab_path = PORT / "data/silentgems/horizon/creative_tab/tab.json"
    tab = json.loads(tab_path.read_text())
    tab_items = [i for i in tab["items"] if "_lamp" not in i]
    lang_path = PORT / "assets/silentgems/lang/en_us.json"
    lang = json.loads(lang_path.read_text())
    lang = {key: value for key, value in lang.items() if "_lamp" not in key}
    for gem, title in GEMS:
        for suffix, lit, inverted, item in STATES:
            block = f"{gem}_lamp{suffix}"
            out[Path(f"data/silentgems/horizon/block/{block}.json")] = block_decl(
                lit, item
            ).encode()
            out[Path(f"assets/silentgems/blockstates/{block}.json")] = blockstate(
                block
            ).encode()
            out[Path(f"assets/silentgems/models/block/{block}.json")] = block_model(
                block, f"{gem}_lamp{'_on' if lit else ''}"
            ).encode()
            drop = f"{gem}_lamp_inverted_on" if inverted else f"{gem}_lamp"
            out[Path(f"data/silentgems/loot_table/blocks/{block}.json")] = loot_table(
                block, drop
            ).encode()
            if item:
                out[Path(f"assets/silentgems/items/{block}.json")] = item_definition(
                    block
                ).encode()
                tab_items.append(f"silentgems:{block}")
                label = f"Inverted {title} Lamp" if inverted else f"{title} Lamp"
                lang[f"block.silentgems.{block}"] = label
            out[Path(f"assets/silentgems/textures/block/{gem}_lamp{'_on' if lit else ''}.png")] = (
                texture(gem, lit).read_bytes()
            )
        out[Path(f"data/silentgems/recipe/{gem}_lamp.json")] = lamp_recipe(gem).encode()
        out[Path(f"data/silentgems/recipe/{gem}_lamp_inverted_on.json")] = (
            inverted_recipe(gem).encode()
        )
    tab["items"] = tab_items
    out[tab_path.relative_to(PORT)] = text(tab).encode()
    out[lang_path.relative_to(PORT)] = text(lang).encode()
    out[Path("data/c/tags/item/dusts/redstone.json")] = dust_tag(
        "minecraft:redstone"
    ).encode()
    out[Path("data/c/tags/item/dusts/glowstone.json")] = dust_tag(
        "minecraft:glowstone_dust"
    ).encode()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="do not write; fail on a difference")
    args = parser.parse_args()
    written = stale = 0
    for path, body in sorted(files().items()):
        target = PORT / path
        if target.is_file() and target.read_bytes() == body:
            continue
        if args.check:
            print(f"stale: {path}", file=sys.stderr)
            stale += 1
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        written += 1
    if args.check:
        print(f"{stale} stale file(s)", file=sys.stderr)
        return 1 if stale else 0
    print(f"wrote {written} file(s); {len(files())} owned by the lamp slice")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
