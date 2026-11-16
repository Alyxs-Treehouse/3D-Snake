class_name GameCatalog
extends Resource
@export var levels: Array[SnakeLevel] = []
@export var skins: Array[SnakeSkin] = []


func level_by_id(id: String) -> SnakeLevel:
	for level in levels:
		if level.id == id:
			return level
	return null


func skin_by_id(id: String) -> SnakeSkin:
	for skin in skins:
		if skin.id == id:
			return skin
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if levels.is_empty() or skins.is_empty():
		errors.append("Catalog needs levels and skins")
	for group in [levels, skins]:
		var ids := {}
		for item in group:
			if item == null:
				errors.append("Null catalog entry")
				continue
			if ids.has(item.id):
				errors.append("Duplicate catalog id: " + item.id)
			ids[item.id] = true
			errors.append_array(item.validate())
	return errors
