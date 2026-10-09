-- Upgrade cards. Each card has a rarity and either modifies a player's stats
-- table in apply(), or is a "special" card resolved instantly when picked.
-- Every card stacks: abilities are counted (one per copy), and `stack` describes
-- what extra copies do when that isn't obvious from the stat lines.
local Cards = {}

Cards.RARITIES = {
  { id = "common",    name = "Common",    color = { 0.75, 0.75, 0.8 }, weight = 46 },
  { id = "uncommon",  name = "Uncommon",  color = { 0.35, 0.9, 0.45 }, weight = 30 },
  { id = "rare",      name = "Rare",      color = { 0.3, 0.6, 1 },     weight = 15 },
  { id = "epic",      name = "Epic",      color = { 0.75, 0.35, 1 },   weight = 6 },
  { id = "legendary", name = "Legendary", color = { 1, 0.78, 0.2 },    weight = 3 },
}
Cards.rarity = {}
for _, r in ipairs(Cards.RARITIES) do Cards.rarity[r.id] = r end

Cards.list = {
  ---------------------------------------------------------------- Common
  {
    name = "Bouncy", rarity = "common",
    lines = { "+2 bullet bounces", "+10% damage" },
    apply = function(s) s.bounces = s.bounces + 2; s.damage = s.damage * 1.1 end,
  },
  {
    name = "Big Bullet", rarity = "common",
    lines = { "+60% bullet size", "+25% damage", "-15% bullet speed" },
    apply = function(s)
      s.bulletSize = s.bulletSize * 1.6; s.damage = s.damage * 1.25; s.bulletSpeed = s.bulletSpeed * 0.85
    end,
  },
  {
    name = "Quick Reload", rarity = "common",
    lines = { "-45% reload time" },
    apply = function(s) s.reloadTime = s.reloadTime * 0.55 end,
  },
  {
    name = "Fast Ball", rarity = "common",
    lines = { "+70% bullet speed", "+less bullet drop" },
    apply = function(s) s.bulletSpeed = s.bulletSpeed * 1.7; s.bulletGravity = s.bulletGravity * 0.4 end,
  },
  {
    name = "Big Mag", rarity = "common",
    lines = { "+3 ammo", "-10% reload time" },
    apply = function(s) s.ammo = s.ammo + 3; s.reloadTime = s.reloadTime * 0.9 end,
  },
  {
    name = "Double Jump", rarity = "common",
    lines = { "+1 air jump", "+10% move speed" },
    apply = function(s) s.airJumps = s.airJumps + 1; s.speed = s.speed * 1.1 end,
  },
  {
    name = "Heavy Shot", rarity = "common",
    lines = { "+70% damage", "+100% knockback", "-35% fire rate" },
    apply = function(s) s.damage = s.damage * 1.7; s.knockback = s.knockback * 2; s.fireDelay = s.fireDelay * 1.5 end,
  },
  {
    name = "Haste", rarity = "common",
    lines = { "+30% move speed", "+10% jump height" },
    apply = function(s) s.speed = s.speed * 1.3; s.jump = s.jump * 1.05 end,
  },
  {
    name = "Healthy", rarity = "common",
    lines = { "+50 HP" },
    apply = function(s) s.maxHp = s.maxHp + 50 end,
  },
  {
    name = "Shields Up", rarity = "common", block = true,
    lines = { "-40% block cooldown", "+longer block" },
    apply = function(s) s.blockCooldown = s.blockCooldown * 0.6; s.blockTime = s.blockTime + 0.15 end,
  },
  {
    name = "Second Wind", rarity = "common", block = true,
    lines = { "+blocking heals 15 HP" },
    apply = function(s) s.blockHeal = s.blockHeal + 15 end,
  },
  {
    name = "Rocket Jump", rarity = "common",
    lines = { "+shooting blasts you backwards", "+aim down to fly" },
    apply = function(s) s.recoil = s.recoil + 450 end,
  },
  {
    name = "Moon Shoes", rarity = "common",
    lines = { "+45% less gravity on you", "+floaty, higher jumps" },
    apply = function(s) s.gravityMul = s.gravityMul * 0.55; s.jump = s.jump * 0.8 end,
  },
  {
    name = "Scavenger", rarity = "common",
    lines = { "+hits refund 1 ammo", "+hits cancel your reload" },
    apply = function(s) s.scavenger = s.scavenger + 1 end,
  },
  {
    name = "Glass Cannon", rarity = "common",
    lines = { "+100% damage", "-50% HP" },
    apply = function(s) s.damage = s.damage * 2; s.maxHp = s.maxHp * 0.5 end,
  },
  {
    name = "Sharpshooter", rarity = "common",
    lines = { "+40% bullet speed", "+50% less spread", "+10% damage" },
    apply = function(s) s.bulletSpeed = s.bulletSpeed * 1.4; s.spread = s.spread * 0.5; s.damage = s.damage * 1.1 end,
  },
  {
    name = "Wide Shot", rarity = "common",
    lines = { "+2 bullets per shot", "+wider spread", "-30% damage" },
    apply = function(s) s.bullets = s.bullets + 2; s.spread = s.spread + 0.3; s.damage = s.damage * 0.7 end,
  },
  {
    name = "Featherweight", rarity = "common",
    lines = { "+25% less gravity on you", "+15% move speed", "-20 HP" },
    apply = function(s) s.gravityMul = s.gravityMul * 0.75; s.speed = s.speed * 1.15; s.maxHp = s.maxHp - 20 end,
  },
  {
    name = "Thick Skin", rarity = "common",
    lines = { "+30 HP", "+take 3 less damage from every hit" },
    apply = function(s) s.maxHp = s.maxHp + 30; s.armor = s.armor + 3 end,
  },
  {
    name = "Quick Hands", rarity = "common",
    lines = { "+33% fire rate" },
    apply = function(s) s.fireDelay = s.fireDelay * 0.75 end,
  },
  {
    name = "Extended Barrel", rarity = "common",
    lines = { "+1 ammo", "+20% bullet speed" },
    apply = function(s) s.ammo = s.ammo + 1; s.bulletSpeed = s.bulletSpeed * 1.2 end,
  },
  {
    name = "Rubber Bullets", rarity = "common",
    lines = { "+1 bullet bounce", "+60% knockback", "-10% damage" },
    apply = function(s) s.bounces = s.bounces + 1; s.knockback = s.knockback * 1.6; s.damage = s.damage * 0.9 end,
  },
  {
    name = "Bulwark", rarity = "common", block = true,
    lines = { "+longer block", "-15% block cooldown", "+20 HP" },
    apply = function(s) s.blockTime = s.blockTime + 0.1; s.blockCooldown = s.blockCooldown * 0.85; s.maxHp = s.maxHp + 20 end,
  },
  {
    name = "Spring Legs", rarity = "common",
    lines = { "+15% jump power" },
    apply = function(s) s.jump = s.jump * 1.15 end,
  },
  {
    name = "Steady Aim", rarity = "common",
    lines = { "+60% less spread", "+15% damage", "-10% fire rate" },
    apply = function(s) s.spread = s.spread * 0.4; s.damage = s.damage * 1.15; s.fireDelay = s.fireDelay * 1.1 end,
  },
  {
    name = "Hollow Points", rarity = "common",
    lines = { "+25% damage", "-15% bullet speed" },
    apply = function(s) s.damage = s.damage * 1.25; s.bulletSpeed = s.bulletSpeed * 0.85 end,
  },
  {
    name = "Light Rounds", rarity = "common",
    lines = { "+50% less bullet drop", "+15% bullet speed" },
    apply = function(s) s.bulletGravity = s.bulletGravity * 0.5; s.bulletSpeed = s.bulletSpeed * 1.15 end,
  },
  {
    name = "Regeneration", rarity = "common",
    lines = { "+heal 3 HP per second" },
    apply = function(s) s.regen = s.regen + 3 end,
  },
  {
    name = "Small Frame", rarity = "common",
    lines = { "+smaller body (harder to hit)", "+10% move speed", "-15 HP" },
    apply = function(s) s.radius = s.radius - 3; s.speed = s.speed * 1.1; s.maxHp = s.maxHp - 15 end,
  },
  {
    name = "Last Round", rarity = "common",
    lines = { "+the last bullet in your magazine deals +100% damage" },
    stack = "+100% more per extra copy",
    apply = function(s) s.lastRound = s.lastRound + 1 end,
  },

  ---------------------------------------------------------------- Uncommon
  {
    name = "Supply Drop", rarity = "uncommon", block = true,
    lines = { "+blocking instantly reloads", "-10% block cooldown" },
    stack = "+1 bonus round above max ammo per extra copy",
    apply = function(s) s.blockReload = s.blockReload + 1; s.blockCooldown = s.blockCooldown * 0.9 end,
  },
  {
    name = "Rear Guard", rarity = "uncommon",
    lines = { "+also fires a shot behind you" },
    stack = "+1 back shot per copy",
    apply = function(s) s.backShot = s.backShot + 1 end,
  },
  {
    name = "Buckshot", rarity = "uncommon",
    lines = { "+4 bullets per shot", "+wide spread", "-55% damage" },
    apply = function(s) s.bullets = s.bullets + 4; s.spread = s.spread + 0.5; s.damage = s.damage * 0.45 end,
  },
  {
    name = "Tank", rarity = "uncommon",
    lines = { "+100 HP", "+bigger body", "-15% move speed" },
    apply = function(s) s.maxHp = s.maxHp + 100; s.radius = s.radius + 5; s.speed = s.speed * 0.85 end,
  },
  {
    name = "Leech", rarity = "uncommon",
    lines = { "+50% lifesteal" },
    apply = function(s) s.lifesteal = s.lifesteal + 0.5 end,
  },
  {
    name = "Spray", rarity = "uncommon",
    lines = { "+230% fire rate", "+4 ammo", "+spread", "-55% damage" },
    apply = function(s)
      s.fireDelay = s.fireDelay * 0.3; s.ammo = s.ammo + 4; s.spread = s.spread + 0.15; s.damage = s.damage * 0.45
    end,
  },
  {
    name = "Poison", rarity = "uncommon",
    lines = { "+hits poison for 60% dmg", "-15% damage" },
    apply = function(s) s.poison = s.poison + 0.6; s.damage = s.damage * 0.85 end,
  },
  {
    name = "Shockwave", rarity = "uncommon", block = true,
    lines = { "+blocking releases a shockwave", "+wave hurts, knocks back and erases bullets" },
    apply = function(s) s.shockwave = s.shockwave + 1 end,
  },
  {
    name = "Empower", rarity = "uncommon", block = true,
    lines = { "+after blocking, your next shot deals double damage" },
    stack = "+1 empowered shot per copy",
    apply = function(s) s.empower = s.empower + 1 end,
  },
  {
    name = "Cloak", rarity = "uncommon", block = true,
    lines = { "+blocking turns you nearly invisible for 1.5s", "+homing can't track you" },
    apply = function(s) s.cloak = s.cloak + 1.5 end,
  },
  {
    name = "Rocket", rarity = "uncommon",
    lines = { "+bullets accelerate in flight", "+25% damage", "-launch slowly" },
    apply = function(s) s.bulletSpeed = s.bulletSpeed * 0.45; s.accel = s.accel + 2200; s.damage = s.damage * 1.25 end,
  },
  {
    name = "Frost", rarity = "uncommon",
    lines = { "+hits slow the enemy by 50% for 2s" },
    apply = function(s) s.frost = s.frost + 2 end,
  },
  {
    name = "Berserker", rarity = "uncommon",
    lines = { "+up to +100% damage as your HP drops" },
    apply = function(s) s.berserk = s.berserk + 1 end,
  },
  {
    name = "Martyr", rarity = "uncommon",
    lines = { "+explode violently when you die" },
    apply = function(s) s.martyr = s.martyr + 1 end,
  },
  {
    name = "Underdog", rarity = "uncommon",
    lines = { "+20% damage per point you're behind" },
    apply = function(s) s.underdog = s.underdog + 1 end,
  },
  {
    name = "Reflector", rarity = "uncommon", block = true,
    lines = { "+bullets you block come back as 1 extra bullet" },
    stack = "+1 extra reflected bullet per copy",
    apply = function(s) s.reflect = s.reflect + 1 end,
  },
  {
    name = "Parry", rarity = "uncommon", block = true,
    lines = { "+blocking an attack instantly recharges your block" },
    stack = "parries heal 10 HP per extra copy",
    apply = function(s) s.parry = s.parry + 1 end,
  },
  {
    name = "Thorns", rarity = "uncommon",
    lines = { "+enemies that hit you take 25% of the damage back" },
    stack = "+25% per copy",
    apply = function(s) s.thorns = s.thorns + 0.25 end,
  },
  {
    name = "Spite", rarity = "uncommon",
    lines = { "+after you take damage, your next shot deals +60% damage" },
    stack = "+60% per copy",
    apply = function(s) s.spite = s.spite + 1 end,
  },
  {
    name = "Executioner", rarity = "uncommon",
    lines = { "+50% damage to enemies below 35% HP" },
    stack = "+50% per copy",
    apply = function(s) s.execute = s.execute + 1 end,
  },
  {
    name = "Combo", rarity = "uncommon",
    lines = { "+each hit within 2s of your last adds +10% damage (up to 5 hits)" },
    stack = "+10% per hit per copy",
    apply = function(s) s.combo = s.combo + 1 end,
  },
  {
    name = "Sprint Block", rarity = "uncommon", block = true,
    lines = { "+blocking gives +40% move speed for 2s" },
    stack = "+40% speed per copy",
    apply = function(s) s.sprintBlock = s.sprintBlock + 1 end,
  },
  {
    name = "Frostback", rarity = "uncommon",
    lines = { "+enemies that hit you are slowed for 1.5s" },
    stack = "+1.5s per copy",
    apply = function(s) s.frostback = s.frostback + 1.5 end,
  },
  {
    name = "Mine Layer", rarity = "uncommon", block = true,
    lines = { "+blocking drops a mine at your feet" },
    stack = "+1 mine per copy",
    apply = function(s) s.mineLayer = s.mineLayer + 1 end,
  },
  {
    name = "Static Field", rarity = "uncommon",
    lines = { "+enemies near you take 8 damage per second" },
    stack = "+8 damage per second per copy",
    apply = function(s) s.static = s.static + 8 end,
  },
  {
    name = "Quickdraw", rarity = "uncommon",
    lines = { "+your first shot after a reload deals +50% damage" },
    stack = "+50% per copy",
    apply = function(s) s.quickdraw = s.quickdraw + 1 end,
  },

  ---------------------------------------------------------------- Rare
  {
    name = "Trickster", rarity = "rare",
    lines = { "+1 bullet bounce", "+60% damage per bounce" },
    apply = function(s) s.bounces = s.bounces + 1; s.bounceDamage = s.bounceDamage + 0.6 end,
  },
  {
    name = "Overclock", rarity = "rare",
    lines = { "+fire rate ramps up to 3x while you hold fire" },
    stack = "ramps up faster and cools down slower per copy",
    apply = function(s) s.spinup = s.spinup + 1 end,
  },
  {
    name = "Explosive", rarity = "rare",
    lines = { "+bullets explode", "-25% fire rate" },
    apply = function(s) s.explosion = s.explosion + 70; s.fireDelay = s.fireDelay * 1.33 end,
  },
  {
    name = "Homing", rarity = "rare",
    lines = { "+bullets gently curve toward the enemy", "-20% bullet speed" },
    apply = function(s) s.homing = s.homing + 1.6; s.bulletSpeed = s.bulletSpeed * 0.8 end,
  },
  {
    name = "Mayhem", rarity = "rare",
    lines = { "+5 bullet bounces", "-15% damage" },
    apply = function(s) s.bounces = s.bounces + 5; s.damage = s.damage * 0.85 end,
  },
  {
    name = "Blink", rarity = "rare", block = true,
    lines = { "+blocking teleports you where you aim" },
    apply = function(s) s.blink = s.blink + 220 end,
  },
  {
    name = "Splitter", rarity = "rare",
    lines = { "+bullets split into 3 on their first wall hit" },
    stack = "splits again on 1 more wall hit per copy",
    apply = function(s) s.split = s.split + 1 end,
  },
  {
    name = "Sniper", rarity = "rare",
    lines = { "+damage grows the farther bullets fly", "+30% bullet speed", "-35% fire rate" },
    apply = function(s) s.distDamage = s.distDamage + 1; s.bulletSpeed = s.bulletSpeed * 1.3; s.fireDelay = s.fireDelay * 1.5 end,
  },
  {
    name = "Decay", rarity = "rare",
    lines = { "+damage you take is dealt slowly over 4s" },
    stack = "+2s longer per extra copy",
    apply = function(s) s.decay = s.decay + 1 end,
  },
  {
    name = "Echo", rarity = "rare",
    lines = { "+every shot echoes 2 more times for free", "-30% damage" },
    apply = function(s) s.burst = s.burst + 2; s.damage = s.damage * 0.7 end,
  },
  {
    name = "Sticky Mines", rarity = "rare",
    lines = { "+spent bullets stick to walls as mines", "+mines explode near the enemy" },
    stack = "+40% mine trigger and blast radius per extra copy",
    apply = function(s) s.sticky = s.sticky + 1 end,
  },
  {
    name = "Piercing Rounds", rarity = "rare",
    lines = { "+bullets pass through 1 player", "-10% damage" },
    stack = "+1 player per copy",
    apply = function(s) s.pierce = s.pierce + 1; s.damage = s.damage * 0.9 end,
  },
  {
    name = "Shrapnel", rarity = "rare",
    lines = { "+bullet impacts burst into 4 shards (25% damage each)" },
    stack = "+4 shards per copy",
    apply = function(s) s.shrapnel = s.shrapnel + 1 end,
  },
  {
    name = "Ricochet Seeker", rarity = "rare",
    lines = { "+bullets home in on enemies after bouncing", "+1 bullet bounce" },
    stack = "stronger homing per copy",
    apply = function(s) s.seek = s.seek + 2; s.bounces = s.bounces + 1 end,
  },
  {
    name = "Last Stand", rarity = "rare",
    lines = { "+once per round, survive a lethal hit with 1 HP" },
    stack = "+1 use per round per copy",
    apply = function(s) s.lastStand = s.lastStand + 1 end,
  },
  {
    name = "Lock and Load", rarity = "rare", block = true,
    lines = { "+blocking gives 1.5s where your shots don't use ammo" },
    stack = "+1s per extra copy",
    apply = function(s) s.lockLoad = s.lockLoad + 1 end,
  },
  {
    name = "Momentum", rarity = "rare",
    lines = { "+up to +50% damage while you're moving fast" },
    stack = "+50% per copy",
    apply = function(s) s.momentum = s.momentum + 1 end,
  },
  {
    name = "Reload Nova", rarity = "rare",
    lines = { "+finishing a reload fires 6 bullets around you" },
    stack = "+6 bullets per copy",
    apply = function(s) s.reloadNova = s.reloadNova + 6 end,
  },
  {
    name = "Adrenaline", rarity = "rare",
    lines = { "+below 50% HP: +40% fire rate and +20% move speed" },
    stack = "+40% fire rate and +20% speed per copy",
    apply = function(s) s.adrenaline = s.adrenaline + 1 end,
  },
  {
    name = "Gravity Block", rarity = "rare", block = true,
    lines = { "+blocking opens a black hole at your position" },
    stack = "+30% pull radius and strength per extra copy",
    apply = function(s) s.gravityBlock = s.gravityBlock + 1 end,
  },

  ---------------------------------------------------------------- Epic
  {
    name = "Lucky Shot", rarity = "epic",
    lines = { "+20% chance to crit", "+crits deal 3x damage" },
    apply = function(s) s.crit = s.crit + 0.2 end,
  },
  {
    name = "Repulsor", rarity = "epic",
    lines = { "+enemy bullets curve away from you" },
    apply = function(s) s.repel = s.repel + 1 end,
  },
  {
    name = "Nova", rarity = "epic", block = true,
    lines = { "+blocking fires a ring of 8 bullets" },
    apply = function(s) s.blockNova = s.blockNova + 8 end,
  },
  {
    name = "Orbiters", rarity = "epic",
    lines = { "+2 orbs circle you", "+orbs destroy enemy bullets", "+orbs damage the enemy" },
    apply = function(s) s.orbs = s.orbs + 2 end,
  },
  {
    name = "Juggernaut", rarity = "epic",
    lines = { "+150 HP", "+immune to knockback", "-20% move speed", "-50% slower block" },
    apply = function(s)
      s.maxHp = s.maxHp + 150; s.radius = s.radius + 8; s.knockbackImmune = true
      s.speed = s.speed * 0.8; s.blockCooldown = s.blockCooldown * 1.5
    end,
  },
  {
    name = "Stasis Field", rarity = "epic",
    lines = { "+enemy bullets near you slow down" },
    stack = "+35% field radius per extra copy",
    apply = function(s) s.stasis = s.stasis + 1 end,
  },
  {
    name = "Swap Shot", rarity = "epic",
    lines = { "+hitting an enemy swaps your places", "1.5s cooldown" },
    stack = "-30% cooldown per extra copy",
    apply = function(s) s.swap = s.swap + 1 end,
  },
  {
    name = "Vampire", rarity = "epic",
    lines = { "+30% lifesteal", "+25 HP" },
    apply = function(s) s.lifesteal = s.lifesteal + 0.3; s.maxHp = s.maxHp + 25 end,
  },
  {
    name = "Overdrive", rarity = "epic",
    lines = { "+60% fire rate", "+3 ammo", "-30% bullet size" },
    apply = function(s) s.fireDelay = s.fireDelay / 1.6; s.ammo = s.ammo + 3; s.bulletSize = s.bulletSize * 0.7 end,
  },
  {
    name = "Titan Rounds", rarity = "epic",
    lines = { "+150% bullet size", "+50% damage", "-30% fire rate" },
    apply = function(s) s.bulletSize = s.bulletSize * 2.5; s.damage = s.damage * 1.5; s.fireDelay = s.fireDelay / 0.7 end,
  },
  {
    name = "Cluster Bombs", rarity = "epic",
    lines = { "+bullets explode", "+explosions split into 3 mini blasts" },
    stack = "+2 mini blasts per extra copy",
    apply = function(s) s.explosion = s.explosion + 40; s.cluster = s.cluster + 1 end,
  },
  {
    name = "Shield Generator", rarity = "epic",
    lines = { "+start every round with a 60 HP shield" },
    stack = "+60 shield per copy",
    apply = function(s) s.shieldMax = s.shieldMax + 60 end,
  },
  {
    name = "Time Warp", rarity = "epic", block = true,
    lines = { "+blocking slows every enemy bullet for 1.5s" },
    stack = "+1s per extra copy",
    apply = function(s) s.timeWarp = s.timeWarp + 1 end,
  },
  {
    name = "Hydra", rarity = "epic",
    lines = { "+hits spawn 2 bullets that fly off (35% damage)" },
    stack = "+1 bullet per extra copy",
    apply = function(s) s.hydra = s.hydra + 1 end,
  },

  ---------------------------------------------------------------- Legendary
  {
    name = "Reroll", rarity = "legendary", special = "reroll",
    lines = { "Reroll these cards" },
  },
  {
    name = "Ghost Bullets", rarity = "legendary",
    lines = { "+bullets pass through walls", "-15% damage" },
    stack = "+25% damage through walls per extra copy (penalty doesn't stack)",
    apply = function(s)
      if s.ghost == 0 then s.damage = s.damage * 0.85 end
      s.ghost = s.ghost + 1
    end,
  },
  {
    name = "Table Flip", rarity = "legendary", special = "tableflip",
    lines = { "Rerolls every card you own", "Rarities stay the same" },
  },
  {
    name = "Phoenix", rarity = "legendary",
    lines = { "+revive once per round at 50% HP" },
    apply = function(s) s.lives = s.lives + 1 end,
  },
  {
    name = "Black Hole", rarity = "legendary",
    lines = { "+bullet impacts open a black hole", "+black holes pull the enemy in" },
    stack = "+30% pull radius and strength per extra copy",
    apply = function(s) s.blackhole = s.blackhole + 1 end,
  },
  {
    name = "Laser", rarity = "legendary",
    lines = { "+your shots become instant laser beams", "+beams bounce off walls" },
    stack = "+50% beam width and +20% damage per extra copy",
    apply = function(s) s.laser = s.laser + 1 end,
  },
  {
    name = "Shrine of Order", rarity = "legendary", special = "shrine",
    lines = { "For each rarity, all your cards of that rarity become copies of one of them", "Card count stays the same" },
  },
  {
    name = "Sentry", rarity = "legendary",
    lines = { "+a turret hovers by you and shoots the nearest enemy", "+turret shots deal 40% of your damage" },
    stack = "turret fires 50% faster per extra copy",
    apply = function(s) s.sentry = s.sentry + 1 end,
  },
  {
    name = "Mirror Shot", rarity = "legendary",
    lines = { "+every shot is also fired from the mirrored side of the arena" },
    stack = "2nd copy: also mirrored top-to-bottom, 3rd: corner-to-corner, more: +15% damage",
    apply = function(s) s.mirror = s.mirror + 1 end,
  },
  {
    name = "Railgun", rarity = "legendary",
    lines = { "+shots become super-fast bolts", "+bolts pierce every player", "+100% damage",
      "-45% fire rate", "-1 ammo" },
    stack = "+50% damage per extra copy",
    apply = function(s)
      if s.railgun == 0 then
        s.bulletSpeed = s.bulletSpeed * 2.5; s.bulletGravity = 0; s.pierce = s.pierce + 10
        s.damage = s.damage * 2; s.fireDelay = s.fireDelay * 1.8; s.ammo = s.ammo - 1
      else
        s.damage = s.damage * 1.5
      end
      s.railgun = s.railgun + 1
    end,
  },
}

-- Stable index per card, used to reference cards over the network, plus a
-- name-based id used in the settings file.
Cards.byId = {}
for i, c in ipairs(Cards.list) do
  c.index = i
  c.id = c.name:lower():gsub("[^%w]+", "_")
  c.baseRarity = c.rarity
  Cards.byId[c.id] = c
end

Cards.DEFAULT_RULES = { pickFrom = 3, picksPerRound = 1, weights = {}, rarity = {}, disabled = {} }
for i, r in ipairs(Cards.RARITIES) do Cards.DEFAULT_RULES.weights[i] = r.weight end
Cards.rules = Cards.DEFAULT_RULES

-- Gameplay rules: { pickFrom, picksPerRound, weights = { per RARITIES index },
-- rarity = { [card index] = rarity id }, disabled = { [card index] = true } }.
-- Sets each card's current rarity / disabled flag (also used when drawing cards).
function Cards.applyRules(rules)
  Cards.rules = rules
  for _, c in ipairs(Cards.list) do
    local r = rules.rarity[c.index]
    c.rarity = (r and Cards.rarity[r]) and r or c.baseRarity
    c.disabled = rules.disabled[c.index] and true or nil
  end
end

-- Can this card be offered to the player right now?
-- Table Flip / Shrine are only offered to a player who already owns cards.
local function offerable(c, player, used)
  if c.disabled or used[c] then return false end
  if c.special and c.special ~= "reroll" and #player.cards == 0 then return false end
  return true
end

-- Deal up to n distinct cards, rolling a rarity for each slot. Only rarities that
-- still have cards to offer take part in the roll; rarities with zero chance are
-- skipped unless nothing else is left. May return fewer than n cards (even none).
function Cards.deal(n, player)
  local weights = Cards.rules.weights
  local hand, used = {}, {}
  while #hand < n do
    local pools, total, any = {}, 0, false
    for i, r in ipairs(Cards.RARITIES) do
      local pool = {}
      for _, c in ipairs(Cards.list) do
        if c.rarity == r.id and offerable(c, player, used) then pool[#pool + 1] = c end
      end
      if #pool > 0 then
        pools[i] = pool
        any = true
        total = total + math.max(0, weights[i] or 0)
      end
    end
    if not any then break end

    local pick
    if total > 0 then
      local x = love.math.random() * total
      for i in ipairs(Cards.RARITIES) do
        local w = pools[i] and math.max(0, weights[i] or 0) or 0
        if w > 0 then
          pick = i
          x = x - w
          if x <= 0 then break end
        end
      end
    else
      local options = {}
      for i in ipairs(Cards.RARITIES) do
        if pools[i] then options[#options + 1] = i end
      end
      pick = options[love.math.random(#options)]
    end

    local pool = pools[pick]
    local c = pool[love.math.random(#pool)]
    used[c] = true
    hand[#hand + 1] = c
  end
  return hand
end

-- A random keepable (non-special, enabled) card of the given rarity, preferring one other than `exclude`.
function Cards.randomOfRarity(rarity, exclude)
  local pool = {}
  for _, c in ipairs(Cards.list) do
    if c.rarity == rarity and not c.special and not c.disabled and c ~= exclude then pool[#pool + 1] = c end
  end
  if #pool == 0 then return exclude end
  return pool[love.math.random(#pool)]
end

function Cards.tableFlip(player)
  for i, c in ipairs(player.cards) do
    player.cards[i] = Cards.randomOfRarity(c.rarity, c)
  end
  player:recompute()
  return string.format("PLAYER %d FLIPPED THE TABLE! %d cards rerolled", player.id, #player.cards)
end

-- Shrine of Order (as in Risk of Rain 2): for each rarity, every card you own of that
-- rarity becomes a copy of one card type you already own of that rarity. Uses each
-- card's current rarity, so cards moved to another rarity in the settings are grouped
-- with the rarity they're in now.
function Cards.shrine(player)
  local types, owned = {}, {} -- rarity id -> distinct card types / count owned
  for _, c in ipairs(player.cards) do
    local r = c.rarity
    types[r] = types[r] or {}
    owned[r] = (owned[r] or 0) + 1
    local seen = false
    for _, t in ipairs(types[r]) do
      if t == c then seen = true end
    end
    if not seen then table.insert(types[r], c) end
  end

  local changes = {}
  for _, r in ipairs(Cards.RARITIES) do
    local list = types[r.id]
    if list then
      local chosen = list[love.math.random(#list)]
      for i, c in ipairs(player.cards) do
        if c.rarity == r.id then player.cards[i] = chosen end
      end
      changes[#changes + 1] = string.format("%d %s became %s", owned[r.id], r.name, chosen.name)
    end
  end
  if #changes == 0 then return "The Shrine of Order found nothing to order" end
  player:recompute()
  return "SHRINE OF ORDER: " .. table.concat(changes, ", ")
end

return Cards
