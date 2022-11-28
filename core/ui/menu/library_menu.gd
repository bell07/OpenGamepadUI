extends Control

@onready var state_manager: StateManager = get_node("/root/Main/StateManager")
@onready var library_manager: LibraryManager = get_node("/root/Main/LibraryManager")
@onready var tab_container: TabContainer = $TabContainer
@onready var all_games_grid: HFlowContainer = $"TabContainer/All Games/MarginContainer/HFlowContainer"
@onready var installed_games_grid: HFlowContainer = $"TabContainer/Installed/MarginContainer/HFlowContainer"

var poster_scene: PackedScene = preload("res://core/ui/components/poster.tscn")
var launcher_scene: PackedScene = preload("res://core/systems/launcher/launcher.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	state_manager.state_changed.connect(_on_state_changed)
	library_manager.library_reloaded.connect(_on_library_reloaded)
	visible = false


func _on_library_reloaded() -> void:
	# Clear our old library entries
	# TODO: Make this better
	for child in all_games_grid.get_children():
		all_games_grid.remove_child(child)
		child.queue_free()
	for child in installed_games_grid.get_children():
		all_games_grid.remove_child(child)
		child.queue_free()
	
	# Load our library entries and add them to all games
	# TODO: Handle launching from multiple providers
	var available: Dictionary = library_manager.get_available()
	var launchers: Array = []
	for entry in available.values():
		for library_id in entry.keys():
			var item: LibraryItem = entry[library_id]
			launchers.push_back(item)
	_populate_grid(all_games_grid, launchers)

	var installed: Dictionary = library_manager.get_installed()
	launchers = []
	for entry in installed.values():
		for library_id in entry.keys():
			var item: LibraryItem = entry[library_id]
			launchers.push_back(item)
	_populate_grid(installed_games_grid, launchers)


# Populates the given grid with library items
func _populate_grid(grid: HFlowContainer, library_items: Array):
	for i in library_items:
		var item: LibraryItem = i
		
		# Build a poster for each library item
		var poster: TextureButton = poster_scene.instantiate()
		poster.library_item = item
		poster.layout = poster.LAYOUT_MODE.PORTRAIT
		poster.text = item.name
		
		# TODO: Get texture from somewhere
		#var img: Texture2D = item.texture
		#poster.texture_normal = img
		
		# Build a launcher from the library item
		var launcher: Launcher = launcher_scene.instantiate()
		launcher.cmd = item.command
		launcher.args = item.args
		poster.add_child(launcher)
		
		# Add the poster to the grid
		grid.add_child(poster)


func _on_state_changed(from: StateManager.State, to: StateManager.State, _data: Dictionary) -> void:
	visible = state_manager.has_state(StateManager.State.LIBRARY)
	if not visible:
		return
	if visible and to == StateManager.State.IN_GAME:
		state_manager.remove_state(StateManager.State.LIBRARY)

	# Focus the first entry on state change
	for child in all_games_grid.get_children():
		child.grab_focus.call_deferred()
		break


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	var num_tabs: int = tab_container.get_tab_count()
	var next_tab: int = tab_container.current_tab
	if event.is_action_pressed("ogui_tab_right"):
		next_tab += 1
	if event.is_action_pressed("ogui_tab_left"):
		next_tab -= 1
	
	if next_tab < 0:
		next_tab = num_tabs - 1
	if next_tab + 1 > num_tabs:
		next_tab = 0
	tab_container.current_tab = next_tab


func _on_tab_container_tab_changed(tab: int) -> void:
	# Get the child container to grab focus
	var container: ScrollContainer = tab_container.get_child(tab)
	var grid: HFlowContainer = container.get_child(0).get_child(0)
	
	# Focus the first entry on tab change
	for child in grid.get_children():
		child.grab_focus.call_deferred()
		break
