extends Control

@onready var client: TubeClient = get_node("/root/Client")

@onready var create: Button = $VBoxContainer/PanelContainer2/VBoxContainer/Button2
@onready var join: Button = $VBoxContainer/PanelContainer/VBoxContainer/Button

@onready var generated_code: RichTextLabel = $VBoxContainer/PanelContainer2/VBoxContainer/HSplitContainer/RichTextLabel
@onready var input_field: LineEdit = $VBoxContainer/PanelContainer/VBoxContainer/HBoxContainer/Line


func _on_generated_pressed() -> void:
    client.leave_session()
    client.create_session()
    Signals.server_created.emit(str(1))
    generated_code.text = client.session_id

func _on_join_pressed() -> void:
    if client.session_id != "":
        client.leave_session()
    client.join_session(input_field.text)