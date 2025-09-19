class_name Equipment
extends RefCounted

@export var id: String = ""
@export var equipment_name: String = "Equipment"
@export var description: String = ""
@export var slot: String = "weapon"
@export var rarity: String = "common"
@export var level_requirement: int = 1

var modifiers: Array[StatProjector.StatModifier] = []
var equipped_to: BattleUnit = null

func _init(_id: String = "", _name: String = "", _slot: String = "weapon") -> void:
    id = _id
    equipment_name = _name
    slot = _slot

func add_stat_modifier(stat: String, op: StatProjector.StatModifier.Op, value: float, priority: int = 0) -> void:
    var mod_id = id + "_" + stat + "_" + str(modifiers.size())
    var mod = StatProjector.StatModifier.new(
        mod_id,
        op,
        value,
        priority,
        [stat],
        -1.0
    )
    modifiers.append(mod)

func add_additive_stat(stat: String, value: float, priority: int = 0) -> void:
    add_stat_modifier(stat, StatProjector.StatModifier.Op.ADD, value, priority)

func add_multiplicative_stat(stat: String, value: float, priority: int = 0) -> void:
    add_stat_modifier(stat, StatProjector.StatModifier.Op.MUL, value, priority)

func equip_to(unit: BattleUnit) -> bool:
    if equipped_to != null:
        push_error("Equipment already equipped to another unit")
        return false
    
    equipped_to = unit
    
    for mod in modifiers:
        for stat in mod.applies_to:
            if unit.stat_projectors.has(stat):
                unit.stat_projectors[stat].add_modifier(mod)
    
    unit.recalculate_stats()
    return true

func unequip_from(unit: BattleUnit) -> void:
    if equipped_to != unit:
        push_error("Equipment not equipped to this unit")
        return
    
    for mod in modifiers:
        for stat in mod.applies_to:
            if unit.stat_projectors.has(stat):
                unit.stat_projectors[stat].remove_modifier(mod)
    
    equipped_to = null
    unit.recalculate_stats()

func get_stat_bonuses() -> Dictionary:
    var bonuses = {}
    
    for mod in modifiers:
        for stat in mod.applies_to:
            if not bonuses.has(stat):
                bonuses[stat] = {"add": 0.0, "mul": 1.0}
            
            match mod.op:
                StatProjector.StatModifier.Op.ADD:
                    bonuses[stat].add += mod.value
                StatProjector.StatModifier.Op.MUL:
                    bonuses[stat].mul *= mod.value
    
    return bonuses

func is_equipped() -> bool:
    return equipped_to != null

func can_equip(unit: BattleUnit) -> bool:
    return not is_equipped()

func clone() -> Equipment:
    var new_equipment = Equipment.new(id, equipment_name, slot)
    new_equipment.description = description
    new_equipment.rarity = rarity
    new_equipment.level_requirement = level_requirement
    
    for mod in modifiers:
        new_equipment.modifiers.append(StatProjector.StatModifier.new(
            mod.id,
            mod.op,
            mod.value,
            mod.priority,
            mod.applies_to.duplicate(),
            mod.expires_at_unix
        ))
    
    return new_equipment

static func create_weapon(name: String, attack_bonus: float, rarity: String = "common") -> Equipment:
    var weapon = Equipment.new("weapon_" + name.to_lower().replace(" ", "_"), name, "weapon")
    weapon.rarity = rarity
    weapon.add_additive_stat("attack", attack_bonus, 10)
    return weapon

static func create_armor(name: String, defense_bonus: float, rarity: String = "common") -> Equipment:
    var armor = Equipment.new("armor_" + name.to_lower().replace(" ", "_"), name, "armor")
    armor.rarity = rarity
    armor.add_additive_stat("defense", defense_bonus, 10)
    return armor

static func create_accessory(name: String, stat_bonuses: Dictionary, rarity: String = "common") -> Equipment:
    var accessory = Equipment.new("accessory_" + name.to_lower().replace(" ", "_"), name, "accessory")
    accessory.rarity = rarity
    
    for stat in stat_bonuses:
        var bonus = stat_bonuses[stat]
        if typeof(bonus) == TYPE_DICTIONARY:
            if bonus.has("add"):
                accessory.add_additive_stat(stat, bonus.add, 5)
            if bonus.has("mul"):
                accessory.add_multiplicative_stat(stat, bonus.mul, 15)
        else:
            accessory.add_additive_stat(stat, bonus, 5)
    
    return accessory
