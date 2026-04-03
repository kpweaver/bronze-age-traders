# Project Overview: BronzeAgeTraders

## The Core Vision
This project is an open-world, grid-based roguelike set in a mythic Bronze Age Mediterranean/Near-East world. It heavily draws mechanical and aesthetic inspiration from *Caves of Qud*. The world is harsh, arid, and driven by deep simulation (fatigue, material degradation, trade, and history) rather than standard high-fantasy tropes.

## Tech Stack & Architecture
* **Engine:** Godot 4.x (Standard Version). 
* **Language:** GDScript ONLY. Do not write C# or suggest .NET solutions.
* **Renderer:** Compatibility (OpenGL) to ensure lightweight 2D performance.
* **Visual Style:** "Simulated Terminal." The game uses a `TileMapLayer` combined with an ASCII/CP437 spritesheet to render the world. 
* **UI Architecture:** UI is built using native Godot Control nodes on a separate `CanvasLayer` sitting above the terminal map, allowing for crisp, deep, and complex menus (trading, character sheets, crafting).

## Aesthetic & Tone
* **Palette:** Sun-baked terracottas, oxidized copper teals, deep lapis lazuli, bronze (#CD7F32), and arid sand colors.
* **Post-Processing:** Use Godot CanvasItem Shaders to add subtle CRT curves, scanlines, and glow to the ASCII tiles, mimicking an ancient, glowing terminal.
* **Atmosphere:** Deep history, brutal survival, city-state politics, and mythic undertones. 

## Core Gameplay Systems
1. **The Grid:** Turn-based, entity-component-like movement on a discrete grid. 
2. **Fatigue & Hydration:** Desert survival is paramount. Actions drain stamina and hydration.
3. **Bronze Age Materials:** Equipment relies on period-accurate materials (stone, copper, tin, bronze). Weapon degradation and material properties are key combat factors.
4. **Information as Currency:** Rumors, reputations with city-states, and uncovering ancient ruins are as important as combat.

## System Instructions for Claude Code (AI Directives)
When writing code for this project, you must adhere to the following rules:
* **Autonomy:** Use the Godot MCP to inspect `.tscn` files and project structures before creating new scripts.
* **No Boilerplate Bloat:** Keep GDScript files clean, modular, and well-commented. Prefer composition over deep inheritance.
* **Signal Discipline:** Use Godot's signal system for decoupling UI from game logic. (e.g., `Player` emits `fatigue_changed`, `UIManager` updates the bar).
* **TileMap Layering:** World generation should manipulate the `TileMapLayer` directly via script, using cell coordinates (Vector2i).
* **Visuals over Math:** If a complex UI menu is needed, prefer creating Godot `Control` node structures (VBoxContainer, GridContainer) in the scene file rather than doing manual position math in GDScript.