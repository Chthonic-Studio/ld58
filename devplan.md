Symbiotic Engine: 48-Hour Execution Plan
Project: Symbiotic Engine
Goal: Implement a 2D Incremental Strategy-Puzzle Game with Synergies and an Entropy/Blight Mechanic within 48 hours.

This plan prioritizes implementation based on technical dependencies and focuses on achieving the core synergy loop (Critical MVP) before adding the primary conflict mechanic (Blight).

Technical Architecture Overview
System/Concept

Type

Responsibility

Rationale (Best Practice)

TileData

Resource (.tres)

Defines all Node properties: Cost, Base Generation, Texture, and the String-keyed synergy_rules dictionary.

Decouples content data from game logic.

ResourceManager

Autoload (Singleton)

Global tracking of current_resources and safe currency transactions. Emits resources_updated signal.

Single source of truth for the economy.

GridManager

Node (2D)

Manages the 2D grid state, Node placement, and the complex Synergy Calculation logic.

Centralizes spatial logic and the core puzzle mechanic.

Communication

Signals

Used exclusively for system communication.

Enforces clean, decoupled architecture.

🚀 Execution Phase Breakdown
Phase 1: Core Systems (The Engine Starts)
Focus on establishing data structures and the basic framework.

Step

System

Primary Focus / Goal

Status

1.

TileData Script

Define class_name and all core @export properties. (Complete data structure).

COMPLETE (Design Confirmed)

2.

ResourceManager

Implement class_name, current_resources, and transactional methods (add_resources/spend_resources). (Economic backbone).

TO DO (Next Script)

3.

Tile Scene

Create Node2D scene with Sprite2D and implement the tile_clicked signal with grid coordinates. (Physical grid element).

TO DO

4.

GridManager Setup

Initialize the 2D grid (Dictionary) and implement initial place_node logic. (Basic world structure).

TO DO

Phase 2: Core Loop Functionality (The Puzzle)
Focus on implementing the actual gameplay loop and resource flow. Critical MVP requires this phase to be complete.

Step

System

Primary Focus / Goal

Status

5.

GridManager Logic

Implement get_neighbors(pos) and the complex calculate_total_generation() (The Synergy loop logic).

TO DO

6.

GameManager

Implement the main "Tick" timer. Connect the GridManager output to the ResourceManager input. (The main game loop coordinator).

TO DO

7.

Basic UI

Implement the resource display (connecting to resources_updated signal) and a simple node placement menu.

TO DO

Phase 3: Conflict, Content, and Polish
Focus on adding the challenge, depth, and presentation layer.

Step

System

Primary Focus / Goal

Status

8.

BlightManager

Implement random spawn and the spread mechanic. Blight must disable tiles in the GridManager. (Core conflict).

TO DO

9.

Defensive Nodes

Create 3-5 new TileData resources for defensive, advanced resource, and utility nodes. (Content depth).

TO DO

10.

Game Feel & Polish

Add visual feedback (synergy lines, Blight effects) and sound design. (Quality pass based on Game Feel Best Practices).

TO DO
