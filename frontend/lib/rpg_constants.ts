export interface CoreAttributes {
  vit: number;
  str: number;
  arc: number;
  def: number;
  agi: number;
  crt: number;
  res: number;
  lck: number;
}

export const ATTRIBUTE_DESCRIPTIONS = {
  vit: "Vitality — Max Health & Health Regeneration",
  str: "Strength — Physical Weapon Attack Rating",
  arc: "Arcana — Elemental & Ability Scaling",
  def: "Defense — Soft-capped Armor Damage Reduction",
  agi: "Agility — Movement Speed & Dash Stamina Efficiency",
  crt: "Critical — Critical Strike Chance & Multiplier",
  res: "Resistance — Negative Status Buildup & Duration Reduction",
  lck: "Luck — High-tier Loot Drops & Substat Quality Weight",
};

export const WEAPON_CLASSES = [
  { id: "longsword", name: "Longsword", baseDmg: 34, strScale: 1.4, arcScale: 1.1, agiScale: 0.5, desc: "Balanced mid-range slashes and reliable parry counters." },
  { id: "twin_blades", name: "Twin Blades", baseDmg: 22, strScale: 0.6, arcScale: 0.4, agiScale: 1.75, desc: "Ultra-fast flurry attacks with high critical hit scaling." },
  { id: "great_hammer", name: "Great Hammer", baseDmg: 58, strScale: 2.1, arcScale: 0.2, agiScale: 0.1, desc: "Heavy crushing strikes with hyper-armor and armor shred." },
  { id: "scythe", name: "Scythe", baseDmg: 42, strScale: 1.1, arcScale: 1.2, agiScale: 0.9, desc: "Sweeping harvest attacks with built-in lifesteal and execution." },
  { id: "bow", name: "Bow", baseDmg: 28, strScale: 0.5, arcScale: 0.8, agiScale: 1.6, desc: "Long-range piercing shots that slow advancing foes." },
  { id: "arcane_staff", name: "Arcane Staff", baseDmg: 36, strScale: 0.2, arcScale: 2.4, agiScale: 0.4, desc: "Homing starlight bolts that regenerate ability energy." },
  { id: "void_blade", name: "Void Blade", baseDmg: 46, strScale: 1.3, arcScale: 1.5, agiScale: 1.4, desc: "Dimensional slashes that ignore armor and trigger void rifts." },
];

export const SKILL_BRANCHES = [
  { id: "WARDEN", name: "Warden", color: "text-emerald-400", desc: "Defense, Shield, Parry, Recovery" },
  { id: "REAVER", name: "Reaver", color: "text-rose-400", desc: "Melee, Combo, Crit, Execution" },
  { id: "ARCANE", name: "Arcane", color: "text-cyan-400", desc: "Ability Power, Elemental Effects, Cooldown" },
  { id: "VOID", name: "Void", color: "text-purple-400", desc: "Corruption, High-Risk Abilities, Rule Disruption" },
];

export const ARTIFACT_SLOTS = ["Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece"] as const;

export const ARTIFACT_SETS = [
  { id: "verdant", name: "Verdant Guardian", bonus2: "+15% Max HP", bonus4: "10% HP/Stamina restore on parry", bonus6: "20% DMG reduction near roots", bonus8: "+50% Nature crit dmg" },
  { id: "drowned", name: "Drowned Oath", bonus2: "+15% Stamina Regen", bonus4: "Immunity to hazard slow; +20% Dash dist", bonus6: "Dodge emits tidal wave", bonus8: "Attacks summon abyssal tentacles" },
  { id: "ashen", name: "Ashen Sovereign", bonus2: "+15 DEF, +20% Fire Resist", bonus4: "Attacks ignite with Hellfire", bonus6: "Molten retributive blast on hit", bonus8: "<50% HP grants +60% Melee Fire DMG" },
  { id: "crimson", name: "Crimson Rite", bonus2: "+15% Crit DMG", bonus4: "Crits siphon 3% Max HP", bonus6: "+35% DMG to bleeding targets", bonus8: "Hemorrhage detonates 15% target HP" },
  { id: "machinist", name: "Machinist's Core", bonus2: "+15% Attack Speed", bonus4: "Shock chains to 2 extra foes", bonus6: "Parry shreds 30% enemy armor", bonus8: "Overcharge: +50% speed & 0 stamina cost" },
  { id: "dream", name: "Dreamwoven", bonus2: "+20% Energy Regen", bonus4: "Dash spawns illusionary decoy", bonus6: "-25% Cooldowns", bonus8: "Reality Rift on perfect parry" },
  { id: "null", name: "Nullborn", bonus2: "+20 to All 8 Attributes", bonus4: "Bosses cannot adapt defenses", bonus6: "+5% DMG per 10% missing HP", bonus8: "Dimensional Fracture: Resets all CDs & 5s immunity" },
];

export function calculateDerivedStats(stats: CoreAttributes, weaponIndex: number = 0, upgradeLevel: number = 0) {
  const weapon = WEAPON_CLASSES[weaponIndex] || WEAPON_CLASSES[0];
  const wepBaseDmg = weapon.baseDmg * (1.0 + upgradeLevel * 0.10);
  const physicalDmg = wepBaseDmg + (stats.str * weapon.strScale) + (stats.arc * weapon.arcScale) + (stats.agi * weapon.agiScale);
  const maxHealth = 100 + (stats.vit * 12.5);
  const armor = stats.def * 4;
  const dmgReductionPct = (armor / (armor + 100)) * 100;
  const critRatePct = Math.min(75, Math.max(5, 5 + (stats.crt * 0.8)));
  const critMultiplier = 1.5 + (stats.crt * 0.02);
  const effectiveHp = maxHealth / (1 - (dmgReductionPct / 100));
  const moveSpeedPct = (1.0 + (stats.agi * 0.015)) * 100;

  return {
    physicalDmg: Math.round(physicalDmg),
    maxHealth: Math.round(maxHealth),
    dmgReductionPct: dmgReductionPct.toFixed(1),
    critRatePct: critRatePct.toFixed(1),
    critMultiplier: critMultiplier.toFixed(2),
    effectiveHp: Math.round(effectiveHp),
    moveSpeedPct: moveSpeedPct.toFixed(1),
  };
}
