class_name UnitVisual
extends Node2D

@export var unit_color: Color = Color.WHITE
@export var team_color: Color = Color.BLUE

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var status_container: HBoxContainer = $StatusContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var battle_unit: BattleUnit

func _ready() -> void:
    if not sprite:
        _create_visual_components()
    
    if battle_unit:
        _setup_from_unit()

func _create_visual_components() -> void:
    # Create sprite
    sprite = Sprite2D.new()
    sprite.name = "Sprite2D"
    add_child(sprite)
    
    # Create a simple colored square as placeholder
    var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
    image.fill(unit_color)
    var texture = ImageTexture.create_from_image(image)
    sprite.texture = texture
    
    # Create health bar
    health_bar = ProgressBar.new()
    health_bar.name = "HealthBar"
    health_bar.size = Vector2(80, 10)
    health_bar.position = Vector2(-40, -50)
    health_bar.modulate = Color.GREEN
    health_bar.show_percentage = false
    add_child(health_bar)
    
    # Create name label
    name_label = Label.new()
    name_label.name = "NameLabel"
    name_label.position = Vector2(-40, -70)
    name_label.add_theme_font_size_override("font_size", 14)
    add_child(name_label)
    
    # Create status container
    status_container = HBoxContainer.new()
    status_container.name = "StatusContainer"
    status_container.position = Vector2(-40, 40)
    add_child(status_container)
    
    # Create animation player
    animation_player = AnimationPlayer.new()
    animation_player.name = "AnimationPlayer"
    add_child(animation_player)
    _create_animations()

func _create_animations() -> void:
    var attack_anim = Animation.new()
    attack_anim.length = 0.5
    
    var pos_track = attack_anim.add_track(Animation.TYPE_VALUE)
    attack_anim.track_set_path(pos_track, NodePath("Sprite2D:position"))
    attack_anim.track_insert_key(pos_track, 0.0, Vector2(0, 0))
    attack_anim.track_insert_key(pos_track, 0.2, Vector2(20, 0))
    attack_anim.track_insert_key(pos_track, 0.5, Vector2(0, 0))
    
    var anim_lib = AnimationLibrary.new()
    anim_lib.add_animation("attack", attack_anim)
    
    var hurt_anim = Animation.new()
    hurt_anim.length = 0.3
    
    var color_track = hurt_anim.add_track(Animation.TYPE_VALUE)
    hurt_anim.track_set_path(color_track, NodePath("Sprite2D:modulate"))
    hurt_anim.track_insert_key(color_track, 0.0, Color.WHITE)
    hurt_anim.track_insert_key(color_track, 0.15, Color.RED)
    hurt_anim.track_insert_key(color_track, 0.3, Color.WHITE)
    
    anim_lib.add_animation("hurt", hurt_anim)
    
    animation_player.add_animation_library("", anim_lib)

func setup(unit: BattleUnit) -> void:
    battle_unit = unit
    if is_inside_tree():
        _setup_from_unit()

func _setup_from_unit() -> void:
    if not battle_unit:
        return
    
    name_label.text = battle_unit.unit_name
    
    # Set team color
    if battle_unit.team == 1:
        team_color = Color.CYAN
        sprite.modulate = Color.CYAN
    else:
        team_color = Color.ORANGE
        sprite.modulate = Color.ORANGE
    
    # Connect signals
    battle_unit.stat_changed.connect(_on_stat_changed)
    battle_unit.unit_died.connect(_on_unit_died)
    battle_unit.status_applied.connect(_on_status_applied)
    battle_unit.status_removed.connect(_on_status_removed)
    
    update_health_bar()
    update_status_display()

func update_health_bar() -> void:
    if not battle_unit:
        return
    
    var health_percent = battle_unit.get_health_percentage()
    health_bar.max_value = 1.0
    health_bar.value = health_percent
    
    # Change color based on health
    if health_percent < 0.3:
        health_bar.modulate = Color.RED
    elif health_percent < 0.6:
        health_bar.modulate = Color.YELLOW
    else:
        health_bar.modulate = Color.GREEN

func update_status_display() -> void:
    if not battle_unit:
        return
    
    # Clear existing status icons
    for child in status_container.get_children():
        child.queue_free()
    
    # Add text labels for each status
    for status in battle_unit.status_effects:
        var status_label = Label.new()
        status_label.text = status.effect_name.left(3).to_upper()
        status_label.add_theme_font_size_override("font_size", 10)
        
        # Color based on buff/debuff
        if status.is_debuff:
            status_label.modulate = Color.RED
        else:
            status_label.modulate = Color.GREEN
        
        status_container.add_child(status_label)

func play_attack_animation() -> void:
    if animation_player.has_animation_library(""):
        animation_player.play("attack")

func play_hurt_animation() -> void:
    if animation_player.has_animation_library(""):
        animation_player.play("hurt")

func play_heal_animation() -> void:
    var tween = get_tree().create_tween()
    tween.tween_property(sprite, "modulate", Color.GREEN, 0.2)
    tween.tween_property(sprite, "modulate", team_color, 0.2)

func play_skill_animation(skill_name: String) -> void:
    match skill_name:
        "Fireball":
            _play_fire_effect()
        "Frost Bolt":
            _play_ice_effect()
        "Heal":
            play_heal_animation()
        _:
            play_attack_animation()

func _play_fire_effect() -> void:
    var tween = get_tree().create_tween()
    tween.tween_property(sprite, "modulate", Color.ORANGE_RED, 0.1)
    tween.tween_property(sprite, "modulate", team_color, 0.3)

func _play_ice_effect() -> void:
    var tween = get_tree().create_tween()
    tween.tween_property(sprite, "modulate", Color.LIGHT_BLUE, 0.1)
    tween.tween_property(sprite, "modulate", team_color, 0.3)

func show_damage_number(damage: float) -> void:
    var damage_label = Label.new()
    damage_label.text = str(int(damage))
    damage_label.position = Vector2(0, -30)
    damage_label.add_theme_font_size_override("font_size", 24)
    
    if damage > 0:
        damage_label.modulate = Color.RED
    else:
        damage_label.modulate = Color.GREEN
    
    add_child(damage_label)
    
    # Animate the damage number
    var tween = get_tree().create_tween()
    tween.tween_property(damage_label, "position", Vector2(0, -60), 0.5)
    tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
    tween.tween_callback(damage_label.queue_free)

func _on_stat_changed(stat_name: String, new_value: float) -> void:
    if stat_name == "health":
        update_health_bar()

func _on_unit_died() -> void:
    var tween = get_tree().create_tween()
    tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.3), 0.5)
    tween.parallel().tween_property(sprite, "rotation", PI/4, 0.5)

func _on_status_applied(status: StatusEffect) -> void:
    update_status_display()

func _on_status_removed(status: StatusEffect) -> void:
    update_status_display()
