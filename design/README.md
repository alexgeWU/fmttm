# Hat Layering System — Generated Assets (v2)

Proof-of-concept assets for **Section 4 (Modular Generation)** of the Art & UI
spec. All pieces are 128x128 transparent PNGs, drawn on the same anchor grid,
so any brim + crown + band + add-on combination lines up automatically.

Style note: everything here is code-generated flat vector art (Python +
Pillow), matching the "vector-style 2D sprite" option in the spec's Art
Direction section. It's a working placeholder set your artist can reskin
piece-by-piece without touching the layering logic.

## What changed in v2

- **10 of everything** (was 5): 10 brims, 10 crowns, 10 bands, 10 add-ons.
- **Brim and crown now share one material system.** Each of the 10 materials
  (cardboard, felt, leather, straw, titanium, velvet, tweed, pinstripe,
  pearl_grey, trilby_noir) has exactly one texture function, used identically
  for both its brim and its crown — so `brim_felt.png` and `crown_felt.png`
  are guaranteed to match, not just coincidentally similar. Only the
  *silhouette* differs between the two (a brim is a flat oval/ring; a crown
  is a dome/box/plate sitting on top), matched to what that material would
  realistically be shaped like (straw → boater brim, leather → wide slouch
  brim, pearl_grey → narrow tilted snap brim, etc).
- **No outline/rim color on brims** (the gold trim from v1 is gone).
- **`pearl_grey` and `trilby_noir` are modeled on real hats Sinatra wore**,
  replacing the earlier `copper`/`patent_leather` materials — see the note
  below.

## The two Sinatra-referenced hats

Per period accounts and today's "Sinatra replica" hats sold by hatters like
Miller Hats and Fedoras.com:

- **`pearl_grey`** — a steel/pearl-grey felt fedora with a narrow ~2 1/8"
  snap brim and a tight-pinch "teardrop" crown, worn at a tilt. This is the
  hat most people picture when they think of Sinatra.
- **`trilby_noir`** — a near-black trilby: narrower brim and a distinctly
  shorter crown than the fedora above. Some sources argue this, not the
  fedora, was actually his more common day-to-day hat.

Both are recreations of a real hat *style*, not Sinatra's likeness — no face,
no portrait, nothing depicting him as a person. That said, if this game
ships commercially, I'd rename the material keys to something neutral (e.g.
`steel_grey` / `noir_trilby`) rather than keep his name as a literal asset
identifier — hat *styles* aren't protected, but his name and likeness are
actively managed by his estate, and "his name is in our shipped game files"
is an easy, avoidable risk. Happy to do that rename if you want it; the
descriptive names above are already neutral, so no action is needed unless
you also want the internal function names changed.

## What's in each folder

| Folder | Count | Names |
|---|---|---|
| `brims/` | 10 | same 10 names as crowns (see below) |
| `crowns/` | 10 | cardboard, felt, leather, straw, titanium, velvet, tweed, pinstripe, pearl_grey, trilby_noir |
| `bands/` | 10 | cotton, silk, spiked, dynamo, chrono, velvet_ribbon, brass_rivet, houndstooth, neon_magenta, pearl_strand |
| `addons/` | 10 | paperclip, playing_card, matchstick, fuzzy_dice, golden_coin, feather, harmonica, poker_chip, bullet_casing, horseshoe |
| `previews/contact_sheet.png` | 1 | every piece + 10 sample combos, for quick reference |
| `previews/combos/` | 10 | one fully-assembled hat per material, brim+crown matched, cycling through a different band + add-on each |

10 x 10 x 10 x 10 = **10,000** unique hat combinations from these 40 files.

## Godot integration

Matches the workflow described in Section 4 of the spec: 4 `Sprite2D` nodes
stacked bottom to top (brim → crown → band → add-on).

```gdscript
@onready var brim  := $HatLayers/Brim
@onready var crown := $HatLayers/Crown
@onready var band  := $HatLayers/Band
@onready var addon := $HatLayers/Addon

func apply_hat(hat: Dictionary) -> void:
    brim.texture  = load("res://art/hats/brims/brim_%s.png"   % hat["material"])
    crown.texture = load("res://art/hats/crowns/crown_%s.png" % hat["material"])
    band.texture  = load("res://art/hats/bands/band_%s.png"   % hat["band"])
    addon.texture = load("res://art/hats/addons/addon_%s.png" % hat["addon"])
```

Note `brim` and `crown` now both read from the same `hat["material"]` key,
since they're always the same material by design. Drop the four folders into
`res://art/hats/` and this snippet works as-is in both `player.gd` and
`gacha.gd`.

If you'd rather let brim and crown vary independently again (e.g. a straw
brim on a titanium crown, for a mismatched comedic look), just give them
separate dictionary keys (`hat["brim"]` / `hat["crown_material"]`) — the
files support that too, since they're just as pastable in any combination.

## Trait keys (for your hat dictionary / gacha table)

- `material` (brim + crown): `cardboard` `felt` `leather` `straw` `titanium` `velvet` `tweed` `pinstripe` `pearl_grey` `trilby_noir`
- `band`: `cotton` `silk` `spiked` `dynamo` `chrono` `velvet_ribbon` `brass_rivet` `houndstooth` `neon_magenta` `pearl_strand`
- `addon`: `paperclip` `playing_card` `matchstick` `fuzzy_dice` `golden_coin` `feather` `harmonica` `poker_chip` `bullet_casing` `horseshoe`

## Regenerating or restyling

`generate_hats.py` (included) is the full generator. Every material, shape,
and detail is a small, named function, so you can swap a color, tweak a
shape, or add an 11th material without touching anything else. Re-run with
`python3 generate_hats.py`.
