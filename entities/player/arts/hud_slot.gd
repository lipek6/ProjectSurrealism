class_name HudSlot extends Control

@export var text_label : RichTextLabel
@export var icon_rect  : TextureRect

func set_text(value: String) -> void:
	if text_label:
		text_label.text = value
		text_label.modulate.a = 1.0


func set_icon(texture: Texture2D) -> void:
	if icon_rect:
		icon_rect.texture = texture
		# Instantly hide the icon block if no texture is passed
		icon_rect.visible = (texture != null)
