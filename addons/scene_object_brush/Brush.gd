@tool
extends Node3D
class_name Brush

@export_category("Brush Settings")
@export var brushSize : float = 1
@export var brushDensity : int = 10
@export var useSurfaceNormal := true
@export var limitToBody: StaticBody3D = null

@export_category("Paintable Settings")
@export var paintableObject: PackedScene
#@export_group("Paintable size")
@export var minSize: float = 0.8
@export var maxSize: float = 1

@export_group("Random Rot")
@export var randomRotMin := Vector3.ZERO
@export var randomRotMax := Vector3.ZERO

const indicatorHeight := 0.25

var cursorPos: Vector3
const IndicatorShader: Shader = preload("res://addons/object_brush/indicator.gdshader")

func getRandomSize():
	return randf_range(minSize, maxSize)
	
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
