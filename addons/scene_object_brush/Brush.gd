@tool
extends Node3D
class_name Brush

## Brush size in meters
@export var brushSize : float = 1
## Spawned objects per brush radius 
@export var brushDensity : int = 10

@export_category("Paintable Settings")
## Scene (asset) to paint
@export var paintableObjects: Array[PackedScene]
@export var minSize: float = 1
@export var maxSize: float = 1
@export var projectOnSurfaceNormal := false

@export_group("Paintable Random Rotation")
@export var randomRotMin := Vector3.ZERO
@export var randomRotMax := Vector3.ZERO

@export_category("OPTIONAL Brush Settings")
## Limit brush to certain static bodies, leave empty for any static body
@export var limitToBodies: Array[StaticBody3D]

const indicatorHeight := 0.25
const IndicatorShader: Shader = preload("indicator.gdshader")
var cursorPos: Vector3

func getRandomSize():
	return randf_range(minSize, maxSize)

func getRandomObjectIndex():
	return randf_range(0, paintableObjects.size())

func isPaintableObjectsValid() -> bool:
	if (paintableObjects.any(func(obj): return obj == null)):
		paintableObjects = paintableObjects.filter(func(obj): return obj != null)
	return paintableObjects.size() != 0
	
func getRotation():
	var x = randf_range(deg_to_rad(randomRotMin.x), deg_to_rad(randomRotMax.x))
	var y = randf_range(deg_to_rad(randomRotMin.y), deg_to_rad(randomRotMax.y))
	var z = randf_range(deg_to_rad(randomRotMin.z), deg_to_rad(randomRotMax.z))
	
	return Vector3(x, y, z)


#TODO: optimise
func draw_line(pos1: Vector3, pos2: Vector3, color = Color.WHITE_SMOKE, persist_frames: int = 1):
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	return await queue_free_draw(mesh_instance, persist_frames)

#TODO: optimise
#ref: https://github.com/Ryan-Mirch/Line-and-Sphere-Drawing
func draw_sphere(pos: Vector3, radius = 0.05, color = Color.WHITE, persist_frames: int = 1):
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.rings = 8
	sphere_mesh.radial_segments = 16
	
	var material := ShaderMaterial.new()
	material.shader	= IndicatorShader
	
	mesh_instance.mesh = sphere_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos

	sphere_mesh.radius = radius
	sphere_mesh.height = radius*2
	sphere_mesh.material = material
	
	material.set_shader_parameter("albedo", Color(0,0,0,0))
	material.set_shader_parameter("wire_color", color)
	
	material.set_shader_parameter("wire_width", 0.4)
	material.set_shader_parameter("wire_smoothness", 0)
	
	return await queue_free_draw(mesh_instance, persist_frames)

func queue_free_draw(mesh_instance: MeshInstance3D, persist_frames: int):
	self.add_child(mesh_instance)
	
	for i in range(persist_frames):
		await get_tree().process_frame
	
	if(is_instance_valid(mesh_instance)):
		mesh_instance.queue_free()
