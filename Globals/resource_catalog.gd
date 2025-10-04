# Autoload Singleton: Indexes all TileData resources available in the project.
# This allows other systems (like the UI build menu) to get a list of all
# placeable tiles without needing to know file paths.
extends Node

# A dictionary of all loaded TileData resources, keyed by their 'id' property.
var tiles: Dictionary = {}

# This function is called when the node enters the scene tree for the first time.
# It scans the designated folder for .tres files, loads them, and catalogs them.
func _ready() -> void:
	_load_all_tile_data("res://Resources/Tiles/")


# How to use:
# In another script (e.g., a UI builder), you can get a specific tile's data via:
# var harvester_data: TileData = ResourceCatalog.tiles.get(&"harvester_basic")
# Or get all available tiles:
# var all_tiles: Array = ResourceCatalog.tiles.values()

# Scans a given directory path for '.tres' files, loads them as TileData,
# and stores them in the 'tiles' dictionary, keyed by the resource's 'id'.
func _load_all_tile_data(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("ResourceCatalog could not open path: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource: Resource = load("%s%s" % [path, file_name])
			if resource is Tile_Data:
				var tile_data: Tile_Data = resource
				if tile_data.id == &"":
					push_warning("TileData file has no 'id': %s" % file_name)
				else:
					tiles[tile_data.id] = tile_data
		file_name = dir.get_next()
