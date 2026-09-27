# Master Game Design Document: Fly Me to the Moon 
*(Version 2.0 - Combined Concept & Production Blueprint)*

## 1. 🎩 Executive Summary & High-Level Concept
A fast-paced, keyboard-controlled roguelite in a **Top-Down 2.5D perspective**. You play as a modest robotic character, but the true star of the show is your procedurally generated, fully 3D Fedora. The game blends the intense action of a brawler (*Hades*) with the hyper-incremental progression of *Johnny Upgrade* and the addictive roster management of a gacha game. Set in a retro-futuristic, jazz-noir world inspired by Frank Sinatra's "Fly Me to the Moon".

### Core Pillars (Do Not Deviate)
1. **The Hat is Everything:** The hat is the only 3D object in a 2D world. It dictates all player stats, skills, and visual focus.
2. **Die to Progress:** The player *must* die to engage with the gacha mechanics and upgrade systems. Death is the start of the reward loop.
3. **Casino-Jazz Aesthetic:** 1950s Sinatra swagger mixed with the dopamine hit of a slot machine.

---

## 2. 🔄 Game Flow & State Machine
The game operates in a strict, cyclical loop. Code states are as follows:
- **STATE_BOOT**: Splash screens -> Load Save Data -> Transition to `STATE_MENU`.
- **STATE_MENU**: 'Start Game' (loads `STATE_HUB`), 'Settings' (Audio/Controls), 'Quit'.
- **STATE_HUB (The Jazz Lounge)**: 
  - A safe 2D zone. 
  - Access the **Roster Screen** to equip hats.
  - Access the **Johnny Upgrade Store** to spend Rhythm Points.
  - Walk through the "Stage Door" -> Transitions to `STATE_RUN`.
- **STATE_RUN (Combat Phase)**: 
  - Top-down movement. Clear procedurally chained rooms of enemies.
  - Collect Rhythm Points (RP) dropped by enemies.
  - On HP = 0: Freeze frame, fade to black -> Transition to `STATE_GACHA`.
- **STATE_GACHA (Post-Death Phase)**:
  - Tally RP earned. Allocate Hat Rolls (Base 3).
  - Pull Lever -> Generate 3 Hats -> Open `UI_ROSTER` to resolve inventory.
  - Return to `STATE_HUB`.

---

## 3. 🗄️ The Hat Roster (Inventory System)
Hats act as your "Characters" or "Classes". 
- You start with a limited number of **Hat Slots** (e.g., 3 slots). 
- When you roll a fantastic hat, you save it to your roster permanently.
- If your roster is full, you must discard an old hat to make room for a new one. 
- You can upgrade your roster capacity in the store.

---

## 4. 🎰 The Hat Generation & Rarity System
Hats are procedurally generated using a weighted rarity system.

### The Math & Rarity Tiers
`Total Stats = (Material Base + Brim Base) * (1.0 + (Chroma Boolean ? 1.0 : 0.0))`
There are exactly three rarity tiers for traits. The rarer the trait, the stronger the stats.
- **Common (70% Chance)**: Standard baseline stats and simple abilities.
- **Rare (20% Chance)**: Noticeably stronger, adds secondary effects and elemental damage.
- **Legendary (10% Chance)**: Game-breaking, screen-clearing effects with massive boosts.

### ✨ The "Chroma" Jackpot Mechanic
Every hat generated has a flat **2% chance** to roll as a **Chroma Hat** (shiny/holographic visual effect). A Chroma hat multiplies *all* of the hat's base stats by **1.5x to 2x**, making even a Common hat highly viable, and a Legendary Chroma hat an absolute god-roll.

### 🎲 Full Hat Traits Breakdown
- **Material (Armor / Base HP)**
  - *Common (70%)*: Cardboard (Weak), Felt (Standard)
  - *Rare (20%)*: Leather (Tough), Straw (Lightweight/Speed)
  - *Legendary (10%)*: Titanium (Heavy Armor), Liquid Metal (Regenerating Armor)
- **Color (Element & Damage Type)**
  - *Common (70%)*: Brown (Physical), Grey (Physical)
  - *Rare (20%)*: Crimson (Fire), Midnight (Ice)
  - *Legendary (10%)*: Chrome (Reflects projectiles), Vantablack (Void Execute)
- **Band (Active Skill)**
  - *Common (70%)*: Cotton Band (Small dash)
  - *Rare (20%)*: Silk Band (Long dash, leaves a trail), Spiked Band (AoE spin)
  - *Legendary (10%)*: Dynamo Band (Deployable turret), Chrono-Band (Stop time for 3 seconds)
- **Add-ons (Passives)**
  - *Common (70%)*: Paperclip (+1 Ammo)
  - *Rare (20%)*: Playing Card (Dodge chance), Matchstick (Burn on hit)
  - *Legendary (10%)*: Fuzzy Dice (Random 1x-3x damage multiplier), The Golden Coin (Double all RP earned)
- **Brim Shape (Attack Style / Weapon Type)**
  - *Common (70%)*: Classic Snap (Standard jabs)
  - *Rare (20%)*: Wide Brim (Sweeping AoE), Porkpie (Rapid brawler punches)
  - *Legendary (10%)*: Boater (Throw like a boomerang), Top Hat (Massive ground-pound)

---

## 5. 📈 Economy & Progression (The Upgrade Store)
You begin the game incredibly weak (slow movement, low health). Progression is tied to **Rhythm Points (RP)**. In the Hub, players spend RP on two types of permanent upgrades:
1. **Base Stats**: Chassis Oil (Speed), Reinforced Plating (Health), Servo Motors (Attack).
2. **Meta Upgrades**: *Extra Quarter* (+1 Hat Roll), *Bigger Wardrobe* (+1 Roster Slot), *Loaded Dice* (Improves Rare/Legendary drop rates).

---

## 6. 🗺️ Level, Enemy & Boss Design
- **Environments**: Jazz/noir tropes (The Smoky Bar, The Neon Alleyway, The Grand Casino).
- **Melee Enemy**: "Bouncers" - Slow, heavy hitting, wide telegraphs.
- **Ranged Enemy**: "Paparazzi" - Flashbulbs that stun or damage.
- **Support Enemy**: "The Conductor" - Buffs nearby enemies to attack faster to the beat.
- **Boss Fight**: "The Big Band" - A giant mechanical jukebox.

---

## 7. 🖥️ UI / UX Master Flow
- **HUD (In-Game)**: Red Health Bar (Hearts), Gold RP counter rolling up like a cash register, Active Skill Icon with radial cooldown sweep.
- **UI_ROSTER (Inventory)**: Grid of mannequins holding the saved hats. Selecting a hat displays a "Stat Card" showing a 3D rotating model of the hat, Rarity Colors, and stat numbers. Buttons: "Equip", "Discard".
- **UI_GACHA (The Slot Machine)**: Massive, screen-filling 3-reel slot machine. "PULL" button. Reels spin for exactly 3 seconds, stopping one by one. 3 generated hats pop out.

---

## 8. 🎨 Asset Master List
### 2D Assets (Flat, heavily shadowed, limited palette)
- Player Robot Sprite (Idle, Walk, Dash, Hurt, Death).
- Bouncer & Paparazzi Enemies (Idle, Walk, Attack, Death).
- Environments (Jazz Lounge, Combat Rooms).
### 3D Assets (Vibrant, high polygon, physically based rendering)
- Base Fedora Mesh.
- Brim Variants & Add-on Props (Playing Card, Matchstick, Dice, etc.).
### Audio Master List
- **BGM**: Jazz Lounge (Slow Sax/Bass), Combat (High-BPM Electro-Swing).
- **SFX**: UI (Poker chips clacking), Gacha (Heavy mechanical lever pull, casino jackpot bell), Combat (Brass hits, swooshes).

---

## 9. 🛑 STRICT ROLE DIRECTIVES
*To prevent scope creep, team members must adhere strictly to these bounds.*

### 👉 Lead Programmer (Systems & Gameplay)
1. Build the exact State Machine (Section 2) using grey-boxes.
2. Write the RNG Generator (Section 4). Prove it works by printing generated Hats to the console.
3. **Restriction**: Do not implement combat AI until the UI_ROSTER and UI_GACHA logic perfectly saves and loads to a local file.

### 👉 UI / UX Designer
1. Wireframe the UI_ROSTER and UI_GACHA screens (Section 7). 
2. Design the "Stat Card" so Legendary traits visually scream "RARE" (gold borders, particle effects).
3. **Restriction**: All UI must be navigable by Keyboard ONLY (Arrow keys + Enter/Escape). 

### 👉 Concept Artist
1. Provide orthographic turnarounds for the 2D Robot, Bouncer, and Paparazzi (Section 6).
2. Establish the Color Palette: 2D world is dark (navy, sepia). Hats use neon/saturated colors.
3. **Restriction**: Do not concept any 3D environments.

### 👉 3D Modeler / Technical Artist
1. Model the base hats and add-ons (Section 4). 
2. Set up materials in Godot so the Programmer can swap colors/textures via code.
3. **Restriction**: Ensure all 3D hat models fit precisely on a standardized "head socket" bone on the 2D player sprite.

### 👉 2D Animator
1. Animate the Player and Enemies in 4 directions. 
2. **Restriction**: The player sprite's head *must* remain stable during walk cycles so the attached 3D hat doesn't jitter wildly.

### 👉 Audio Designer / Composer
1. Produce the BGM tracks and Casino/Combat SFX.
2. **Restriction**: Combat sound effects must not drown out the music beat. Mix combat SFX to sit under the brass section of the BGM.
