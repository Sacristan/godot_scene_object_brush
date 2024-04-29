@tool
extends EditorPlugin
class_name BrushEditor

var brush: Brush
var editorCamera: Camera3D
var mouseOverlayPos: Vector2
var lastDrawnMouseOverlayPos: Vector2

var mouseHitPoint: Vector3
var mouseHitNormal: Vector3

enum ButtonStatus {RELEASED, PRESSED}
var drawStatus = ButtonStatus.RELEASED
var eraseStatus = ButtonStatus.RELEASED

const Brush = preload("Brush.gd")

var drawCursor: bool = false
var drawnEver: bool = false

var _prevMouseHitPoint := Vector3.ZERO
var _isDrawDirty := true
var _isEraseDirty := true

## TODO
## benchmark tool 
## customisable indicator color
## support non-planar surfaces
## multiple allowed surfaces
## undo https://docs.godotengine.org/en/stable/classes/class_undoredo.html

var prevMouseHitPoint: Vector3:
	get:
		return _prevMouseHitPoint
	set(value):
		_isDrawDirty = false
		_isEraseDirty = false
		_prevMouseHitPoint = value

func _handles(object):
#	print("_handles")

	if(object is Brush):
		brush = object as Brush
		return object.is_visible_in_tree()

	return false

func _enter_tree():
	#print("editor _enter_tree")
	add_custom_type("Brush", "Node3D", Brush, null)
	set_process(true)
#
func _exit_tree():
	#print("editor_exit_tree")
	remove_custom_type("Brush")
	set_process(false)
	
func _process(delta):
	if(lastDrawnMouseOverlayPos.distance_to(mouseOverlayPos) > 0.0001):
		lastDrawnMouseOverlayPos = mouseOverlayPos
		drawCursor = test()

	if(drawCursor):
		drawHit()
		drawBrush()

func _forward_3d_draw_over_viewport(overlay: Control):
#	print("_forward_3d_draw_over_viewport "+ str(overlay.get_local_mouse_position()))
	mouseOverlayPos = overlay.get_local_mouse_position()

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent):
#	print("_forward_3d_gui_input")
	if(not editorCamera):
		editorCamera = camera
	
	var prevDrawStatus = drawStatus
	var prevEraseStatus = eraseStatus
	
	if event is InputEventMouseButton:
		var buttonEvent = event as InputEventMouseButton
		if buttonEvent.pressed:
			if buttonEvent.button_index == MOUSE_BUTTON_LEFT:
				drawStatus = ButtonStatus.PRESSED
			elif buttonEvent.button_index == MOUSE_BUTTON_RIGHT:
				eraseStatus = ButtonStatus.PRESSED
		else:
			if buttonEvent.button_index == MOUSE_BUTTON_LEFT:
				drawStatus = ButtonStatus.RELEASED
			elif buttonEvent.button_index == MOUSE_BUTTON_RIGHT:
				eraseStatus = ButtonStatus.RELEASED
				
		if(prevDrawStatus == ButtonStatus.PRESSED && drawStatus == ButtonStatus.RELEASED):
			_isDrawDirty = true
		
		if(prevEraseStatus == ButtonStatus.PRESSED && eraseStatus == ButtonStatus.RELEASED):
			_isEraseDirty = true
			
		processMouse()
		
		if(drawStatus == ButtonStatus.PRESSED or eraseStatus == ButtonStatus.PRESSED):
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		
	elif event is InputEventMouseMotion:
		update_overlays()
			
		if drawStatus == ButtonStatus.PRESSED or eraseStatus == ButtonStatus.PRESSED:
			processMouse()
			
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func processMouse():
	if drawStatus == ButtonStatus.PRESSED:
		drawReq()
	if eraseStatus == ButtonStatus.PRESSED:
		eraseReq()

func drawReq():
#	print("drawReq")
	if(_isDrawDirty || mouseHitPoint.distance_to(prevMouseHitPoint) > brush.brushSize):
		prevMouseHitPoint = mouseHitPoint
		draw()

func eraseReq():
#	print("eraseReq")
	if(_isEraseDirty || mouseHitPoint.distance_to(prevMouseHitPoint) > brush.brushSize):
		prevMouseHitPoint = mouseHitPoint
		erase()
	
func erase():
	for child in brush.get_children():
		
		var dist: float = mouseHitPoint.distance_to(child.position)
		
		if(dist < brush.brushSize):
			child.queue_free()
	
func draw():
#	print("draw")
	var localDensity: int = brush.brushDensity
	
	for i in localDensity:
		var dir: Vector3 = Quaternion(Vector3.UP, randf_range(0, 360)) * Vector3.RIGHT;
		
		var spawnPos: Vector3 = (dir * brush.brushSize * randf_range(0.05, 1)) + mouseHitPoint
		spawnObject(spawnPos)

func spawnObject(pos: Vector3):
	var result: Dictionary = raycastTestPos(pos)
	var canPlace: bool = result.wasHit && brush.isPaintableObjectsValid()
	#print(result)
	
	if(canPlace):
		var finalPos: Vector3 = result.hitResult.position
		var normal: Vector3 = result.hitResult.normal
		
		brush.draw_line(finalPos, finalPos + normal * 3, Color.CYAN, 3 * 60)
		
		var rot: Quaternion = Quaternion.from_euler(brush.getRotation())
		#rot = normal * rot
			
		var obj = get_random_object() as Node3D
		brush.add_child(obj)
		obj.owner = get_tree().get_edited_scene_root()
		obj.position = finalPos
		obj.rotation = rot.get_euler()
		obj.scale = Vector3.ONE * brush.getRandomSize()
		obj.name = brush.name + "_" + getUnixTimestamp()

func get_random_object() -> Node3D:
	return brush.paintableObjects[brush.getRandomObjectIndex()].instantiate()

func raycastTestPos(pos: Vector3) -> Dictionary:
	var params = PhysicsRayQueryParameters3D.new()
	params.from = pos + Vector3.UP
	params.to = pos
	
	brush.draw_line(params.from, params.to, Color.YELLOW, 3 * 60)
	
	var result := brush.get_world_3d().direct_space_state.intersect_ray(params)
	
	if result:
		return { "wasHit": true, "hitResult": result }
		
	return { "wasHit": false, "hitResult": result }

func test() -> bool:
	
	var from = editorCamera.global_position
	var dir = editorCamera.project_ray_normal(mouseOverlayPos)
	var to = from + dir * 1000
	
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to

	var result := brush.get_world_3d().direct_space_state.intersect_ray(params)

	if result:
		if result.collider:
			#print("Collided with: ", result.collider.name)
			if(brush.limitToBodies.size() > 0):
				var found: bool = false
				
				for body in brush.limitToBodies:
					#print(body, result.collider)
					if(body == result.collider):
						found = true
						break;
				
				if(!found):
					return false
					
			mouseHitPoint = result.position
			mouseHitNormal = result.normal
			return true
			
	return false
	
func drawHit():
	drawCursorIndicator(0.1, Color.RED)

func drawBrush():
	drawCursorIndicator(brush.brushSize, Color.DARK_BLUE)
	
func drawCursorIndicator(radius: float, color: Color):
	brush.draw_sphere(mouseHitPoint, radius, color)
	
func getUnixTimestamp() -> String:
	return str(Time.get_unix_time_from_system())
