# Fly Me to the Moon — Art & UI Specification Document

This document is for the Graphic Designer, UI/UX Designer, and 3D Modeler. It outlines exactly what assets are needed, what dimensions they should be, and how to integrate them into the Godot Engine project.

## 1. General Art Direction
- **Theme**: Noir Jazz Roguelite.
- **Palette**: Dark navies, sepia tones, golds, crimsons, and neon highlights.
- **Style**: Vector-style 2D sprites (or pre-rendered 3D isometric sprites) for the characters and environments. 

---

## 2. Character Sprites (2D)

All characters are currently using `PlaceholderTexture2D`. You will need to replace these with actual `.png` textures.

### Player Character (The Robot)
- **Node**: `sprite_body` in `scripts/player.gd`
- **Recommended Size**: `64x64` to `128x128` pixels.
- **Details**: Needs to look like a robot. The sprite should face "down" by default. 
- **Animation (Optional)**: If you want animated sprites, you can replace the `Sprite2D` node with an `AnimatedSprite2D` in the Godot Editor and load a SpriteFrames resource.

### Bouncer Enemy (Melee)
- **Node**: `sprite_body` in `scripts/enemy_bouncer.gd`
- **Recommended Size**: `96x96` pixels (big and bulky).
- **Details**: Mafia enforcer/bouncer. Slow and heavy.

### Paparazzi Enemy (Ranged)
- **Node**: `sprite_body` in `scripts/enemy_paparazzi.gd`
- **Recommended Size**: `48x64` pixels (sleek and fast).
- **Details**: A reporter with a camera. Fires flashes.

### Mafia Boss Enemy (Spread Attacker)
- **Node**: `sprite_body` in `scripts/enemy_boss.gd`
- **Recommended Size**: `128x128` or `150x150` pixels.
- **Details**: Giant mob boss. Spawns every 5 rounds. Very tanky.

---

## 3. FX and Projectiles

### Player Attack FX
- **Node**: `attack_fx` in `scripts/player.gd`
- **Recommended Size**: `128x128` pixels.
- **Details**: A sweeping arc or slash effect. It rotates based on the player's facing direction.

### Paparazzi Bullet (Flash Bulb)
- **Node**: Generated dynamically in `_fire()` in `scripts/enemy_paparazzi.gd`
- **Recommended Size**: `16x16` pixels.
- **Details**: A bright white/yellow glowing orb or camera flash.

### Boss Bullet (Spread Fire)
- **Node**: Generated dynamically in `_fire_spread()` in `scripts/enemy_boss.gd`
- **Recommended Size**: `24x24` pixels.
- **Details**: A dark purple or crimson glowing projectile.

---

## 4. The "Hats" (Modular Generation)

The game generates hats procedurally by combining random traits. If you want these to be visually distinct, the best approach is **Modular 2D Layering**.

### The Layering System
Instead of drawing 100 different hats, the artist should draw modular pieces (all exported at the exact same canvas size, e.g., `128x128`, so they perfectly overlap):

1. **Brim Shapes** (Layer 1 - Bottom)
   - Classic Snap, Wide Brim, Porkpie, Boater, Top Hat base.
2. **Crowns / Materials** (Layer 2)
   - Cardboard, Felt, Leather, Straw, Titanium textures mapped to crown shapes.
3. **Bands** (Layer 3)
   - Cotton Band, Silk Band, Spiked Band, Dynamo Band, Chrono-Band.
4. **Add-ons** (Layer 4 - Top)
   - Paperclip, Playing Card, Matchstick, Fuzzy Dice, Golden Coin.

**How to implement in Godot:**
In `player.gd` (and `gacha.gd` for the display), you will create 4 `Sprite2D` nodes stacked on top of each other. The script will read the hat dictionary (e.g., `hat["material"]`) and assign the corresponding `.png` to the correct layer.

---

## 5. UI / UX Assets

The UI is built using Godot's scalable Control nodes (`VBoxContainer`, `HBoxContainer`, `CenterContainer`). You can style them in two ways:

1. **Godot Themes (Programmatic)**: Create a `Theme` resource in Godot. You can define what all Buttons, Labels, and Panels look like (fonts, borders, hover colors). Apply this Theme to the root nodes in `menu.gd`, `hub.gd`, etc.
2. **TextureRects (Image-based)**: Replace `ColorRect` backgrounds with `TextureRect` nodes using your own high-res background art.

### Required UI Screens / Backgrounds:
1. **Main Menu Background**: `1920x1080` (Noir city skyline).
2. **Jazz Lounge Hub Background**: `1920x1080` (Inside a smoky jazz club, piano, stage door).
3. **Combat Room Background**: `1920x1080` (Alleyway, backroom casino, or vault).
4. **Gacha Machine**: A standalone slot machine graphic (approx `600x400`). Needs to look like a mechanical lever machine.

---

## 6. How the Artist / UX Designer Should Work in Godot

Currently, all nodes are generated in GDScript (e.g., `var sprite = Sprite2D.new()`). 

**To take full control over the visual layout:**
1. Open the Godot Editor.
2. Create a new Scene (e.g., a `CharacterBody2D` for the Player).
3. Add your `Sprite2D` nodes, drag your `.png` files in, and position them perfectly.
4. Add an `AnimationPlayer` to animate the sprites.
5. In the existing scripts (like `combat_room.gd`), simply change the `preload` path from the `.gd` script to your new `.tscn` scene file! 

*Example:*
Change: `const PlayerScript = preload("res://scripts/player.gd")`
To: `const PlayerScene = preload("res://scenes/my_player.tscn")`
And spawn it with: `var player = PlayerScene.instantiate()`
