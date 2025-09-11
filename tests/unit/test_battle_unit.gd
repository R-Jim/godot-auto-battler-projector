extends GutTest

var battle_unit: BattleUnit

func before_each():
    battle_unit = BattleUnit.new()
    add_child(battle_unit)
    await get_tree().process_frame
    watch_signals(battle_unit)

func after_each():
    battle_unit.queue_free()

func test_initial_stats():
    assert_eq(battle_unit.stats.health, 100.0)
    assert_eq(battle_unit.stats.max_health, 100.0)
    assert_eq(battle_unit.stats.attack, 10.0)
    assert_eq(battle_unit.stats.defense, 5.0)
    assert_eq(battle_unit.stats.speed, 5.0)
    assert_eq(battle_unit.stats.initiative, 0.0)

func test_projectors_created_for_each_stat():
    for stat_name in battle_unit.stats.keys():
        assert_true(battle_unit.stat_projectors.has(stat_name))
        assert_not_null(battle_unit.stat_projectors[stat_name])
        assert_true(battle_unit.stat_projectors[stat_name] is StatProjector)

func test_get_projected_stat():
    var attack = battle_unit.get_projected_stat("attack")
    assert_eq(attack, 10.0)
    
    # Add modifier and check projection
    battle_unit.stat_projectors["attack"].add_flat_modifier("buff", 5.0)
    attack = battle_unit.get_projected_stat("attack")
    assert_eq(attack, 15.0)

func test_get_projected_stat_unknown():
    var result = battle_unit.get_projected_stat("nonexistent")
    assert_eq(result, 0.0)

func test_take_damage():
    battle_unit.take_damage(30.0)
    # Damage reduced by defense (5), so actual damage = 30 - 5 = 25
    assert_eq(battle_unit.stats.health, 75.0)
    assert_signal_emitted_with_parameters(battle_unit, "stat_changed", ["health", 75.0])

func test_take_damage_minimum():
    # Even with high defense, minimum damage is 1
    battle_unit.stat_projectors["defense"].add_flat_modifier("armor", 1000.0)
    battle_unit.take_damage(10.0)
    assert_eq(battle_unit.stats.health, 99.0)

func test_take_damage_lethal():
    battle_unit.take_damage(200.0)
    assert_eq(battle_unit.stats.health, 0.0)
    assert_signal_emitted(battle_unit, "unit_died")
    assert_false(battle_unit.is_alive())

func test_heal():
    battle_unit.stats.health = 50.0
    battle_unit.heal(30.0)
    assert_eq(battle_unit.stats.health, 80.0)
    assert_signal_emitted_with_parameters(battle_unit, "stat_changed", ["health", 80.0])

func test_heal_capped_by_max_health():
    battle_unit.stats.health = 90.0
    battle_unit.heal(20.0)
    assert_eq(battle_unit.stats.health, 100.0)

func test_heal_respects_projected_max_health():
    battle_unit.stat_projectors["max_health"].add_flat_modifier("buff", 50.0)
    battle_unit.stats.health = 100.0
    battle_unit.heal(30.0)
    assert_eq(battle_unit.stats.health, 130.0)

func test_add_status_effect():
    var status = StatusEffect.new("poison", "Poison", "Deals damage over time", 5.0)
    battle_unit.add_status_effect(status)
    
    assert_true(battle_unit.status_effects.has(status))
    assert_signal_emitted_with_parameters(battle_unit, "status_applied", [status])

func test_add_duplicate_status_effect():
    var status = StatusEffect.new("poison", "Poison", "Deals damage over time", 5.0)
    battle_unit.add_status_effect(status)
    battle_unit.add_status_effect(status)  # Try to add same instance
    
    assert_eq(battle_unit.status_effects.size(), 1)

func test_remove_status_effect():
    var status = StatusEffect.new("poison", "Poison", "Deals damage over time", 5.0)
    battle_unit.add_status_effect(status)
    battle_unit.remove_status_effect(status)
    
    assert_false(battle_unit.status_effects.has(status))
    assert_signal_emitted_with_parameters(battle_unit, "status_removed", [status])

func test_remove_nonexistent_status():
    var status = StatusEffect.new("poison", "Poison", "Deals damage over time", 5.0)
    battle_unit.remove_status_effect(status)  # Should not crash
    assert_true(true)

func test_get_status_list():
    var poison = StatusEffect.new("poison", "Poison", "", 5.0)
    var burn = StatusEffect.new("burn", "Burn", "", 3.0)
    
    battle_unit.add_status_effect(poison)
    battle_unit.add_status_effect(burn)
    
    var status_list = battle_unit.get_status_list()
    assert_eq(status_list.size(), 2)
    assert_true(status_list.has("poison"))
    assert_true(status_list.has("burn"))

func test_add_skill():
    var skill = BattleSkill.new()
    skill.skill_name = "Fireball"
    
    battle_unit.add_skill(skill)
    assert_true(battle_unit.skills.has(skill))
    
    # Adding same skill again shouldn't duplicate
    battle_unit.add_skill(skill)
    assert_eq(battle_unit.skills.size(), 1)

func test_equip_item():
    var sword = Equipment.create_weapon("Iron Sword", 10.0)
    battle_unit.equip_item("weapon", sword)
    
    assert_true(battle_unit.equipment.has("weapon"))
    assert_eq(battle_unit.equipment["weapon"], sword)
    
    # Check modifier was applied
    var attack = battle_unit.get_projected_stat("attack")
    assert_eq(attack, 20.0)  # Base 10 + sword 10

func test_equip_item_replaces_existing():
    var sword1 = Equipment.create_weapon("Iron Sword", 10.0)
    var sword2 = Equipment.create_weapon("Steel Sword", 15.0)
    
    battle_unit.equip_item("weapon", sword1)
    assert_eq(battle_unit.get_projected_stat("attack"), 20.0)
    
    battle_unit.equip_item("weapon", sword2)
    assert_eq(battle_unit.get_projected_stat("attack"), 25.0)  # Base 10 + sword2 15
    assert_eq(battle_unit.equipment["weapon"], sword2)

func test_unequip_item():
    var armor = Equipment.create_armor("Iron Armor", 5.0)
    battle_unit.equip_item("armor", armor)
    assert_eq(battle_unit.get_projected_stat("defense"), 10.0)  # Base 5 + armor 5
    
    battle_unit.unequip_item("armor")
    assert_false(battle_unit.equipment.has("armor"))
    assert_eq(battle_unit.get_projected_stat("defense"), 5.0)  # Back to base

func test_unequip_nonexistent_slot():
    battle_unit.unequip_item("nonexistent")  # Should not crash
    assert_true(true)

func test_recalculate_stats():
    battle_unit.stat_projectors["attack"].add_flat_modifier("buff", 10.0)
    battle_unit.stat_projectors["defense"].add_percentage_modifier("debuff", 0.5)
    
    # Track which stats were updated
    var updated_stats = {}
    battle_unit.stat_changed.connect(func(stat_name, value): updated_stats[stat_name] = value)
    
    battle_unit.recalculate_stats()
    
    # Should have updated all stats
    assert_eq(updated_stats.size(), battle_unit.stats.size())
    for stat_name in battle_unit.stats:
        assert_true(updated_stats.has(stat_name), "Expected stat_changed for " + stat_name)

func test_get_health_percentage():
    assert_eq(battle_unit.get_health_percentage(), 1.0)  # 100/100
    
    battle_unit.stats.health = 50.0
    assert_eq(battle_unit.get_health_percentage(), 0.5)  # 50/100
    
    battle_unit.stats.health = 0.0
    assert_eq(battle_unit.get_health_percentage(), 0.0)  # 0/100

func test_get_health_percentage_with_modified_max():
    battle_unit.stat_projectors["max_health"].add_flat_modifier("buff", 100.0)
    battle_unit.stats.health = 150.0
    assert_eq(battle_unit.get_health_percentage(), 0.75)  # 150/200

func test_get_health_percentage_zero_max():
    battle_unit.stat_projectors["max_health"].set_override("curse", 0.0, 100)
    assert_eq(battle_unit.get_health_percentage(), 0.0)

func test_is_alive():
    assert_true(battle_unit.is_alive())
    
    battle_unit.stats.health = 0.1
    assert_true(battle_unit.is_alive())
    
    battle_unit.stats.health = 0.0
    assert_false(battle_unit.is_alive())
    
    battle_unit.stats.health = -10.0
    assert_false(battle_unit.is_alive())

func test_roll_initiative():
    var initiative = battle_unit.roll_initiative()
    var speed = battle_unit.get_projected_stat("speed")
    
    # Initiative should be speed + random 0-2
    assert_gte(initiative, speed)
    assert_lt(initiative, speed + 2.0)
    assert_eq(battle_unit.stats.initiative, initiative)

func test_reset_initiative():
    battle_unit.roll_initiative()
    assert_gt(battle_unit.stats.initiative, 0.0)
    
    battle_unit.reset_initiative()
    assert_eq(battle_unit.stats.initiative, 0.0)

func test_projection_changed_signal():
    # Watch for the battle unit's stat_changed signal
    watch_signals(battle_unit)
    
    # Add a modifier which should trigger the signal chain
    battle_unit.stat_projectors["attack"].add_flat_modifier("buff", 10.0)
    
    # The stat_changed signal should have been emitted by the battle unit
    assert_signal_emitted(battle_unit, "stat_changed")
    
    # Verify the stat was actually changed
    assert_eq(battle_unit.get_projected_stat("attack"), 20.0)  # 10 base + 10 buff

func test_complex_battle_scenario():
    # Equip items
    var sword = Equipment.create_weapon("Fire Sword", 15.0)
    var armor = Equipment.create_armor("Dragon Scale", 10.0)
    battle_unit.equip_item("weapon", sword)
    battle_unit.equip_item("armor", armor)
    
    # Add status effect (without RuleProcessor dependency)
    var buff = StatusEffect.new("strength", "Strength", "Increases attack", 10.0)
    # Manually add modifier since we can't use RuleProcessor in unit test
    # Use priority 5 (lower than equipment's 10) so multiplication happens after addition
    battle_unit.stat_projectors["attack"].add_percentage_modifier("strength_buff", 1.5, 5, ["attack"], buff.expires_at)
    battle_unit.add_status_effect(buff)
    
    # Verify stats
    var attack = battle_unit.get_projected_stat("attack")
    assert_eq(attack, 37.5)  # (Base 10 + sword 15) * 1.5 = 37.5
    
    var defense = battle_unit.get_projected_stat("defense")
    assert_eq(defense, 15.0)  # Base 5 + armor 10
    
    # Take damage
    battle_unit.take_damage(50.0)
    assert_eq(battle_unit.stats.health, 65.0)  # 100 - (50 - 15) = 65
    
    # Heal
    battle_unit.heal(20.0)
    assert_eq(battle_unit.stats.health, 85.0)
