extends Node2D

var battle: AutoBattler

func _ready() -> void:
    # Create battle manager
    battle = preload("res://src/battle/auto_battler.gd").new()
    battle.use_observer_system = true  # Enable new system
    battle.name = "Battle"
    add_child(battle)
    
    # Create teams
    var team1 = create_team(1, 2)
    var team2 = create_team(2, 2)
    
    # Start battle
    battle.start_battle(team1, team2)
    
    # Connect signals for debugging
    battle.action_performed.connect(_on_action_performed)
    battle.battle_ended.connect(_on_battle_ended)
    
    print("Observer-based battle started!")

func create_team(team_num: int, unit_count: int) -> Array[BattleUnit]:
    var BattleUnit = preload("res://src/battle/battle_unit.gd")
    var BattleSkill = preload("res://src/battle/battle_skill.gd")
    var team: Array[BattleUnit] = []
    
    for i in range(unit_count):
        var unit = BattleUnit.new()
        unit.unit_name = "Team%d_Unit%d" % [team_num, i + 1]
        unit.team = team_num
        unit.stats = {
            "health": 100.0,
            "max_health": 100.0,
            "attack": 20.0 + i * 5,
            "defense": 5.0,
            "speed": 5.0 + i * 2,
            "mana": 50.0,
            "initiative": 0.0
        }
        
        # Add basic attack skill
        var attack_skill = BattleSkill.new()
        attack_skill.skill_name = "Basic Attack"
        attack_skill.base_damage = 25.0
        attack_skill.target_type = "single_enemy"
        attack_skill.resource_cost = 10.0
        attack_skill.resource_type = "mana"
        unit.skills.append(attack_skill)
        
        # Add special skill
        if i == 0:
            var special = BattleSkill.new()
            special.skill_name = "Power Strike"
            special.base_damage = 40.0
            special.target_type = "single_enemy"
            special.resource_cost = 20.0
            special.resource_type = "mana"
            special.cooldown = 3.0
            special.tags.assign(["burst"])
            unit.skills.append(special)
        
        team.append(unit)
    
    return team

func _on_action_performed(unit, action: Dictionary) -> void:
    print("[%.1fs] %s performed %s" % [
        Time.get_unix_time_from_system(), 
        unit.unit_name, 
        action.get("type", "unknown")
    ])
    
    if action.has("skill"):
        print("  Skill: %s" % action.skill.skill_name)
    if action.has("targets"):
        if action.targets is Array:
            for target in action.targets:
                print("  Target: %s" % target.unit_name)
        else:
            print("  Target: %s" % action.targets.unit_name)

func _on_battle_ended(winner_team: int) -> void:
    print("\nBattle ended! Winner: Team %d" % winner_team)
    
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE:
            # Toggle time scale
            if battle and battle.skill_observer:
                battle.skill_observer.time_scale = 0.1 if battle.skill_observer.time_scale > 0.5 else 1.0
                print("Time scale: %.1f" % battle.skill_observer.time_scale)
        elif event.keycode == KEY_D:
            # Debug print
            if battle and battle.skill_observer:
                print("\n=== Observer Debug ===")
                print("Observed units: %d" % battle.skill_observer.observed_units.size())
                print("Active casts: %d" % battle.skill_observer.active_casts.size())
                if battle.skill_observer.action_queue:
                    battle.skill_observer.action_queue.debug_print_queue()
                if battle.observer_battle_context:
                    battle.observer_battle_context.debug_print_state()
