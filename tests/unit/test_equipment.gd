extends GutTest

var equipment: Equipment

func before_each():
    equipment = Equipment.new()

func test_init_with_parameters():
    var equip = Equipment.new("sword_01", "Iron Sword", "weapon")
    assert_eq(equip.id, "sword_01")
    assert_eq(equip.equipment_name, "Iron Sword")
    assert_eq(equip.slot, "weapon")

func test_add_stat_modifier():
    equipment.add_stat_modifier("attack", StatProjector.ModifierOp.ADD, 10.0, 5)
    assert_eq(equipment.modifiers.size(), 1)
    
    var mod = equipment.modifiers[0]
    assert_eq(mod.id, "_attack_0")
    assert_eq(mod.op, StatProjector.ModifierOp.ADD)
    assert_eq(mod.value, 10.0)
    assert_eq(mod.priority, 5)
    assert_eq(mod.applies_to, ["attack"])

func test_add_additive_stat():
    equipment.id = "test_item"
    equipment.add_additive_stat("defense", 5.0, 10)
    
    assert_eq(equipment.modifiers.size(), 1)
    var mod = equipment.modifiers[0]
    assert_eq(mod.op, StatProjector.ModifierOp.ADD)
    assert_eq(mod.value, 5.0)

func test_add_multiplicative_stat():
    equipment.id = "test_item"
    equipment.add_multiplicative_stat("speed", 1.5, 15)
    
    assert_eq(equipment.modifiers.size(), 1)
    var mod = equipment.modifiers[0]
    assert_eq(mod.op, StatProjector.ModifierOp.MUL)
    assert_eq(mod.value, 1.5)

func test_multiple_modifiers():
    equipment.id = "complex_item"
    equipment.add_additive_stat("attack", 10.0)
    equipment.add_multiplicative_stat("attack", 1.2)
    equipment.add_additive_stat("defense", 5.0)
    
    assert_eq(equipment.modifiers.size(), 3)
    # Check unique IDs
    assert_eq(equipment.modifiers[0].id, "complex_item_attack_0")
    assert_eq(equipment.modifiers[1].id, "complex_item_attack_1")
    assert_eq(equipment.modifiers[2].id, "complex_item_defense_2")

func test_is_equipped():
    assert_false(equipment.is_equipped())
    
    equipment.equipped_to = BattleUnit.new()
    assert_true(equipment.is_equipped())

func test_can_equip():
    assert_true(equipment.can_equip(null))  # Can equip if not equipped
    
    equipment.equipped_to = BattleUnit.new()
    assert_false(equipment.can_equip(null))  # Cannot equip if already equipped

func test_get_stat_bonuses():
    equipment.add_additive_stat("attack", 10.0)
    equipment.add_multiplicative_stat("attack", 1.5)
    equipment.add_additive_stat("defense", 5.0)
    equipment.add_multiplicative_stat("speed", 0.8)
    
    var bonuses = equipment.get_stat_bonuses()
    
    assert_true(bonuses.has("attack"))
    assert_eq(bonuses.attack.add, 10.0)
    assert_eq(bonuses.attack.mul, 1.5)
    
    assert_true(bonuses.has("defense"))
    assert_eq(bonuses.defense.add, 5.0)
    assert_eq(bonuses.defense.mul, 1.0)
    
    assert_true(bonuses.has("speed"))
    assert_eq(bonuses.speed.add, 0.0)
    assert_eq(bonuses.speed.mul, 0.8)

func test_clone():
    equipment.id = "original"
    equipment.equipment_name = "Original Item"
    equipment.description = "Test description"
    equipment.slot = "weapon"
    equipment.rarity = "rare"
    equipment.level_requirement = 10
    equipment.add_additive_stat("attack", 15.0, 10)
    equipment.add_multiplicative_stat("speed", 1.2, 5)
    
    var clone = equipment.clone()
    
    # Check basic properties
    assert_eq(clone.id, equipment.id)
    assert_eq(clone.equipment_name, equipment.equipment_name)
    assert_eq(clone.description, equipment.description)
    assert_eq(clone.slot, equipment.slot)
    assert_eq(clone.rarity, equipment.rarity)
    assert_eq(clone.level_requirement, equipment.level_requirement)
    
    # Check modifiers are cloned
    assert_eq(clone.modifiers.size(), 2)
    assert_eq(clone.modifiers[0].value, 15.0)
    assert_eq(clone.modifiers[1].value, 1.2)
    
    # Should not be equipped
    assert_null(clone.equipped_to)
    
    # Should be different objects
    assert_ne(clone, equipment)
    assert_ne(clone.modifiers[0], equipment.modifiers[0])

func test_create_weapon():
    var weapon = Equipment.create_weapon("Fire Sword", 25.0, "epic")
    
    assert_eq(weapon.id, "weapon_fire_sword")
    assert_eq(weapon.equipment_name, "Fire Sword")
    assert_eq(weapon.slot, "weapon")
    assert_eq(weapon.rarity, "epic")
    assert_eq(weapon.modifiers.size(), 1)
    assert_eq(weapon.modifiers[0].value, 25.0)
    assert_eq(weapon.modifiers[0].applies_to, ["attack"])

func test_create_armor():
    var armor = Equipment.create_armor("Dragon Scale", 30.0, "legendary")
    
    assert_eq(armor.id, "armor_dragon_scale")
    assert_eq(armor.equipment_name, "Dragon Scale")
    assert_eq(armor.slot, "armor")
    assert_eq(armor.rarity, "legendary")
    assert_eq(armor.modifiers.size(), 1)
    assert_eq(armor.modifiers[0].value, 30.0)
    assert_eq(armor.modifiers[0].applies_to, ["defense"])

func test_create_accessory_simple():
    var bonuses = {"speed": 10.0, "max_health": 50.0}
    var accessory = Equipment.create_accessory("Swift Ring", bonuses, "rare")
    
    assert_eq(accessory.id, "accessory_swift_ring")
    assert_eq(accessory.equipment_name, "Swift Ring")
    assert_eq(accessory.slot, "accessory")
    assert_eq(accessory.rarity, "rare")
    assert_eq(accessory.modifiers.size(), 2)

func test_create_accessory_complex():
    var bonuses = {
        "attack": {"add": 5.0, "mul": 1.1},
        "defense": {"add": 10.0},
        "speed": {"mul": 1.2}
    }
    var accessory = Equipment.create_accessory("Power Amulet", bonuses)
    
    assert_eq(accessory.modifiers.size(), 4)  # 2 for attack, 1 for defense, 1 for speed
    
    # Verify modifiers
    var attack_mods = []
    var defense_mods = []
    var speed_mods = []
    
    for mod in accessory.modifiers:
        if mod.applies_to.has("attack"):
            attack_mods.append(mod)
        elif mod.applies_to.has("defense"):
            defense_mods.append(mod)
        elif mod.applies_to.has("speed"):
            speed_mods.append(mod)
    
    assert_eq(attack_mods.size(), 2)
    assert_eq(defense_mods.size(), 1)
    assert_eq(speed_mods.size(), 1)

func test_equip_to():
    var unit = BattleUnit.new()
    add_child(unit)
    await get_tree().process_frame
    
    equipment.add_additive_stat("attack", 10.0)
    equipment.add_additive_stat("defense", 5.0)
    
    var result = equipment.equip_to(unit)
    assert_true(result)
    assert_eq(equipment.equipped_to, unit)
    
    # Check modifiers were applied
    assert_eq(unit.get_projected_stat("attack"), 20.0)  # Base 10 + equipment 10
    assert_eq(unit.get_projected_stat("defense"), 10.0)  # Base 5 + equipment 5
    
    unit.queue_free()

func test_equip_to_already_equipped():
    var unit1 = BattleUnit.new()
    var unit2 = BattleUnit.new()
    add_child(unit1)
    add_child(unit2)
    await get_tree().process_frame
    await get_tree().process_frame
    
    equipment.equip_to(unit1)
    var result = equipment.equip_to(unit2)
    
    assert_false(result)
    assert_eq(equipment.equipped_to, unit1)  # Still equipped to first unit
    
    unit1.queue_free()
    unit2.queue_free()

func test_unequip_from():
    var unit = BattleUnit.new()
    add_child(unit)
    await get_tree().process_frame
    
    equipment.add_additive_stat("attack", 10.0)
    equipment.equip_to(unit)
    
    assert_eq(unit.get_projected_stat("attack"), 20.0)
    
    equipment.unequip_from(unit)
    
    assert_null(equipment.equipped_to)
    assert_eq(unit.get_projected_stat("attack"), 10.0)  # Back to base
    
    unit.queue_free()

func test_unequip_from_wrong_unit():
    var unit1 = BattleUnit.new()
    var unit2 = BattleUnit.new()
    add_child(unit1)
    add_child(unit2)
    await get_tree().process_frame
    await get_tree().process_frame
    
    equipment.equip_to(unit1)
    equipment.unequip_from(unit2)  # Try to unequip from wrong unit
    
    assert_eq(equipment.equipped_to, unit1)  # Still equipped to unit1
    
    unit1.queue_free()
    unit2.queue_free()
