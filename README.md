# Symbiotic Engine (LD58)  
A 2D incremental strategy–puzzle game about cultivating synergistic growth under mounting entropy (Blight). Built in Godot 4.5 with a data‑driven, modular architecture optimized for rapid iteration and systemic depth.

---

## 1. High Concept
Place and combine specialized biomechanical tiles on a grid to generate resources via emergent synergies. Over time, Blight spreads—disrupting or disabling tiles—forcing adaptive restructuring. The core tension: optimize a living engine of mutually amplifying parts before entropy overwhelms it.

---

## 2. Core Pillars
1. Synergistic Emergence: Power comes from relationships, not isolated tiles.  
2. Tactical Spatial Economy: Placement order and adjacency matter as much as cost curves.  
3. Pressure via Entropy: Blight escalates complexity and decision urgency.  
4. Clean Modularity: Every system is decoupled via signals for rapid content iteration.  
5. Transparency & Learnability: Players can inspect why outputs occur (planned synergy visualizations).  

---

## 3. Player Fantasy
“I’m an architect of a living network—engineering growth while pruning decay.”

---

## 4. Target Experience
- Session Length: 5–20 minute runs (game-jam scope).
- Audience: Fans of combinatorial puzzles, factory games, roguelite economy loops.
- Platform: Desktop (Mouse-first).

---

## 5. Core Game Loop (Macro)
1. Earn passive + synergy-amplified resources each tick.  
2. Spend resources to place new tiles.  
3. Reconfigure strategy as Blight emerges/spreads.  
4. Unlock advanced defensive / utility tiles.  
5. Survive escalating entropy curve (soft fail = overwhelmed engine).  

---

## 6. Moment-to-Moment Loop
Place Tile → Trigger Recalculation → Observe Output Shift → Plan Next Placement → React to Blight Event.

---

## 7. Systems Design

### 7.1 Tile System
- Defined entirely via `TileData` (custom Resource).
- Contains: cost, base_generation (dictionary keyed by resource type), synergy_rules, category, defensive flags, texture ref, description.
- All balancing done by editing `.tres` resource instances—no code changes required.

### 7.2 Synergy Rules
- Each `TileData` holds a `synergy_rules` dictionary:
	- Keys: string identifiers referencing other tile categories or tags.
	- Values: objects/dicts describing transformation (e.g. additive modifier, multiplier, conditional output).
- Evaluation is adjacency-based (4-directional to start; extensible to 8 or pattern masks).
- Total tile output = base + Σ (validated synergy contributions).
- Order independence: synergy engine designed to be deterministic per state hash.

### 7.3 Resource Economy
- Central `ResourceManager` (Autoload) holds current_resources: `{String: float}`.
- Emits:
	- `resources_updated(current_resources: Dictionary)`
	- `resources_spent(cost: Dictionary)`
	- `resources_generated(delta: Dictionary)`
- Economy Goals:
	- Early scarcity → midgame abundance pivot.
	- Introduce secondary advanced resource via transformation.
	- Defensive / utility tiles consume upkeep in later phase (optional stretch).

### 7.4 Grid System
- `GridManager` owns:
	- `grid: Dictionary` keyed by `Vector2i -> TileInstanceData`.
	- Placement validation (occupied, boundary, future adjacency constraints).
	- Synergy recalculation pipeline.
- Exposes signals:
	- `tile_placed(pos: Vector2i, tile_data: TileData)`
	- `tile_removed(pos: Vector2i)`
	- `grid_changed()`
	- `generation_recalculated(total: Dictionary, per_tile: Dictionary)`
- No direct resource mutation—only emits generation results to GameManager.

### 7.5 Blight System (Phase 3)
- `BlightManager`:
	- Maintains infected set of positions.
	- Periodic spread (weighted by frontier size).
	- Disables generation from affected tiles (soft or total suppression).
	- Emits:
		- `blight_spawned(at: Vector2i)`
		- `blight_spread(updated_positions: Array[Vector2i])`
		- `tile_disabled(at: Vector2i)`
- Defensive tiles mitigate: block spread, cleanse, or convert.

### 7.6 Game Manager (Tick Orchestrator)
- Owns global tick Timer.
- Each tick:
	1. Requests latest generation from GridManager (cached incremental recompute preferred).
	2. Sends result to ResourceManager.
	3. Emits `tick_completed(tick_index, generation_snapshot)`.
- No UI logic here.

### 7.7 UI Layer
- Resource HUD bound to `ResourceManager.resources_updated`.
- Build panel lists available `TileData` assets (pulled from a `ResourceCatalog`).
- Placement feedback: highlight valid cells, preview synergy delta (stretch goal).
- Future: synergy overlay toggle.

### 7.8 Defensive & Utility Tiles (Examples)
| Tile | Role | Mechanic Sketch |
|------|------|-----------------|
| Purifier | Anti-Blight | Prevent spread within radius N. |
| Shield Node | Stability | Reduces negative synergy penalties. |
| Relay | Amplifier | Copies one neighbor’s best synergy rule. |
| Converter | Alchemy | Transforms Resource A -> B with loss. |
| Anchor | Control | Halts Blight growth if central cluster stable. |

---

## 8. Data Model Overview

### 8.1 TileData (Resource)
```
class_name TileData
extends Resource

@export var id: StringName
@export var display_name: String
@export var category: StringName
@export var cost: Dictionary			# {resource_type: float}
@export var base_generation: Dictionary	# {resource_type: float}
@export var synergy_rules: Dictionary	# {rule_key: Dictionary}
@export var texture: Texture2D
@export var description: String
@export var tags: Array[StringName] = []
@export var is_defensive: bool = false
```

### 8.2 In-Grid Instance Record
(Stored in `GridManager.grid[pos]`)
```
{
	"tile_data": TileData,
	"last_generation": {},			# Dictionary
	"cached_synergy": {},			# Optional
	"disabled": false				# Blight state
}
```

### 8.3 Synergy Rule Example
```
# synergy_rules = {
#	"harvester": {"type": "additive", "resource": "biomass", "value": 0.5},
#	"relay": {"type": "multiplier", "target": "biomass", "factor": 1.15},
#	"blight_adjacent": {"type": "penalty", "factor": 0.75}
# }
```
Interpreter in `GridManager` resolves semantic types (extensible registry pattern later).

---

## 9. Signal Topology (Decoupling Contract)

Emitter -> Signal -> Listener(s):
- ResourceManager -> resources_updated -> UI, DebugPanel
- ResourceManager -> resources_generated / resources_spent -> Log / FX
- GridManager -> generation_recalculated -> GameManager (pull or push)
- GridManager -> tile_placed / tile_removed -> UI (overlay), BlightManager (potential triggers)
- GameManager -> tick_completed -> Analytics / Effects
- BlightManager -> tile_disabled / blight_spread -> GridManager (invalidate generation), UI (FX)
- BuildUI -> tile_selected(tile_data) -> PlacementController
- PlacementController -> request_place(tile_data, pos) -> GridManager (validation path)
- GridManager -> placement_result(success, reason) -> PlacementController -> UI feedback

---

## 10. Scene / Node Architecture

| Node / Autoload | Type | Responsibility |
|-----------------|------|----------------|
| ResourceManager (autoload) | Node | Single source of truth for currencies. |
| ResourceCatalog (autoload or static loader) | Node/Helper | Indexes all TileData assets. |
| GameManager | Node | Tick coordination / sequencing. |
| GridManager | Node2D | Spatial state & synergy computation. |
| BlightManager | Node | Entropy lifecycle & interactions. |
| UI root | CanvasLayer | Aggregates HUD, Build Panel, Overlays. |
| Tile (scene) | Node2D | Visual & interaction wrapper for a TileData instance. |

Tile scene composition:
- Node2D (root)
	- Sprite2D
	- (Optional) Overlay / highlight
	- (Optional) AnimationPlayer

---

## 11. Placement & Validation Flow
1. User selects tile in Build UI.
2. Hover preview queries `GridManager` for hypothetical synergy delta (stretch).
3. On click: `PlacementController` emits placement request.
4. `GridManager`:
	- Checks bounds.
	- Checks occupied.
	- (Optional) Future adjacency constraints.
	- Emits result.
5. On success: instantiate visual tile scene, register in grid, trigger recompute.

---

## 12. Synergy Calculation Strategy
Baseline (Jam Scope):
- Full recompute each placement/removal: O(N * k_neighbors * k_rules).
- Acceptable for small grids (< 400 tiles).
Near-Future Optimization:
- Dirty-set propagation: only recalc tiles in radius of changed cell(s).
- Cache hashed neighbor signature per tile; recompute if signature changes.

---

## 13. Blight Design (Phase 3)
- Spawn cadence increases over time or based on total generation.
- Spread chooses from frontier cells (adjacent to infected).
- Disabled tiles produce 0 (or reduced %) until cleansed.
- Strategic pressure: More growth → more heat (spawn probability scaling).
- Anti-snowball lever: defensive tiles consume resources or occupy scarce space.

---

## 14. Progression & Difficulty
- Horizontal expansion → synergy scaling.
- Introduce diminishing returns via soft caps or synergy saturation flags.
- Blight ensures plateau risk unless investing in control layer.

---

## 15. Balancing Framework
- Use JSON/CSV → tool script importer (stretch) OR pure Resource iteration.
- Tuning metrics captured per tick:
	- total_generation curve
	- resource surplus/deficit intervals
	- tile type distribution
- Potential analytics console via DebugPanel.

---

## 16. Tooling (Potential)
- Editor tool script to auto-generate starter `TileData` assets.
- Gizmo overlay for synergy lines (debug only).
- Export synergy matrix preview as markdown for design review.

---

## 17. Extensibility Paths
| Feature | Approach |
|---------|----------|
| Multi-layer grids | Abstract `GridManager` into service; layer ID in keys. |
| Procedural map seeds | Generate blocked cells / blight hotspots. |
| Prestige meta | Persist JSON of unlocked tile sets. |
| Pattern-based synergies | Add shape matcher (masks over grid). |
| Mod support | Load `*.tres` from user folder; dynamic catalog registration. |

---

## 18. Milestones (Mapped to Execution Plan)
Phase 1 (Core Systems):
1. TileData definitions
2. ResourceManager (signals + transactions)
3. Tile scene (input → emit clicked)
4. GridManager (placement + grid dictionary)

Phase 2 (Core Loop):
5. Synergy logic (neighbors + total generation)
6. GameManager tick pipeline
7. Basic UI (resources + placement menu)

Phase 3 (Conflict & Polish):
8. BlightManager (spawn/spread/disable)
9. Defensive + advanced tiles
10. Visual / audio feedback (synergy lines, blight FX)

---

## 19. Risk Register
| Risk | Impact | Mitigation |
|------|--------|------------|
| Over-complex synergy parser | Delays MVP | Start with simple additive/multiplier types only. |
| Performance of full recompute | Late-game slowdown | Implement dirty-tile incremental pass if needed. |
| Blight feels unfair/random | Player frustration | Weighted spread + telegraph + defensive tools. |
| UI opacity (why numbers?) | Player disengagement | Add optional per-tile breakdown panel. |

---

## 20. Glossary
- Synergy: A rules-driven modification applied to a tile’s base generation when adjacency conditions are met.
- Frontier (Blight): Set of non-blighted cells adjacent to blighted cells.
- Disabled Tile: A tile whose generation pipeline is skipped due to Blight.
- Signature: Deterministic hash of a tile’s relevant neighborhood state.

---

## 21. Implementation Notes (Godot 4.5 Guidelines)
- Use tabs for indentation (project rule).
- Use `Signal` declarations at top of each script for clarity.
- Avoid deep inheritance; prefer composition (e.g., attach Behavior scripts if extended).
- Never directly mutate another manager’s internal state—use signals.
- All constant-like enumerations: use `StringName` for speed and memory benefits.

---

## 22. Minimal Script Skeleton Examples

```
# ResourceManager.gd (Autoload)
extends Node
signal resources_updated(current: Dictionary)
signal resources_generated(delta: Dictionary)
signal resources_spent(cost: Dictionary)

var current_resources: Dictionary = {
	"biomass": 0.0,
	"energy": 0.0
}

func add_resources(delta: Dictionary) -> void:
	for k in delta:
		current_resources[k] = (current_resources.get(k, 0.0) + delta[k])
	resources_generated.emit(delta)
	resources_updated.emit(current_resources)

func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if current_resources.get(k, 0.0) < cost[k]:
			return false
	return true

func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		current_resources[k] -= cost[k]
	resources_spent.emit(cost)
	resources_updated.emit(current_resources)
	return true
```

```
# GridManager.gd (Excerpt)
extends Node2D
signal tile_placed(pos: Vector2i, tile_data: TileData)
signal tile_removed(pos: Vector2i)
signal generation_recalculated(total: Dictionary, per_tile: Dictionary)

var grid: Dictionary = {}
var neighbor_dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

func place_tile(pos: Vector2i, tile_data: TileData) -> bool:
	if grid.has(pos):
		return false
	grid[pos] = {
		"tile_data": tile_data,
		"last_generation": {},
		"cached_synergy": {},
		"disabled": false
	}
	tile_placed.emit(pos, tile_data)
	_recalculate_generation()
	return true

func _recalculate_generation() -> void:
	var total := {}
	var per_tile := {}
	for pos in grid.keys():
		var inst = grid[pos]
		var gen = _compute_tile_generation(pos, inst)
		inst.last_generation = gen
		per_tile[pos] = gen
		for k in gen:
			total[k] = (total.get(k, 0.0) + gen[k])
	generation_recalculated.emit(total, per_tile)

func _compute_tile_generation(pos: Vector2i, inst: Dictionary) -> Dictionary:
	if inst.disabled:
		return {}
	var td: TileData = inst.tile_data
	var output: Dictionary = {}
	# Start from base
	for k in td.base_generation:
		output[k] = td.base_generation[k]
	# Apply synergy rules (simplified placeholder)
	for dir in neighbor_dirs:
		var npos = pos + dir
		if not grid.has(npos):
			continue
		var neighbor_td: TileData = grid[npos].tile_data
		# Example rule lookup by category id
		if td.synergy_rules.has(neighbor_td.category):
			var rule = td.synergy_rules[neighbor_td.category]
			_apply_rule(output, rule)
	return output

func _apply_rule(output: Dictionary, rule: Dictionary) -> void:
	match rule.get("type", ""):
		"additive":
			var res = rule.get("resource", "")
			if res != "":
                # Ensure key initialization
				output[res] = output.get(res, 0.0) + rule.get("value", 0.0)
		"multiplier":
			var target = rule.get("target", "")
			if target != "" and output.has(target):
				output[target] *= rule.get("factor", 1.0)
		"penalty":
			for k in output:
				output[k] *= rule.get("factor", 1.0)
		_:
			pass
```

---

## 23. Future Polish Ideas
- Animated synergy link pulses to show active relationships.
- Threat meter forecasting next Blight event.
- Undo last placement (cost refund variant).
- Challenge modes (limited placements, time attack).

---

## 24. License
TBD (Choose before release: MIT recommended for jam openness).

---

## 25. Credits
- Design / Code: (Fill)
- Tools: Godot 4.5, (Asset sources TBD)

---

## 26. Changelog (Seed)
- v0.0.1: Initial architecture scaffolding & GDD commit.

---

## 27. Contribution Guidelines (Short)
1. Maintain tab indentation.
2. New content = new `TileData` resource (do not hardcode).
3. Use signals for all cross-system interactions.
4. Provide doc comments on public functions.
5. Keep commits atomic (one system concern per commit).

---

## 28. Quick Start (Dev)
1. Clone repo.
2. Open in Godot 4.5.
3. Confirm autoloads (ResourceManager, ResourceCatalog).
4. Run main scene (once added) to validate tick loop.
5. Add a new tile: duplicate a `.tres`, adjust cost/base_generation, relaunch.

---

End of GDD / README.
