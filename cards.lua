-- Upgrade cards. Each card has a rarity and either modifies a player's stats
-- table in apply(), or is a "special" card resolved instantly when picked.
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
    name = "Supply Drop", rarity = "common", block = true,
    lines = { "+blocking instantly reloads", "-10% block cooldown" },
    apply = function(s) s.blockReload = true; s.blockCooldown = s.blockCooldown * 0.9 end,
  },
  {
    name = "Rocket Jump", rarity = "common",
    lines = { "+shooting blasts you backwards", "+aim down to fly" },
    apply = function(s) s.recoil = s.recoil + 450 end,
  },
  {
    name = "Lucky Shot", rarity = "common",
    lines = { "+20% chance to crit", "+crits deal 3x damage" },
    apply = function(s) s.crit = s.crit + 0.2 end,
  },
  {
    name = "Moon Shoes", rarity = "common",
    lines = { "+45% less gravity on you", "+floaty, higher jumps" },
    apply = function(s) s.gravityMul = s.gravityMul * 0.55; s.jump = s.jump * 0.8 end,
  },
  {
    name = "Rear Guard", rarity = "common",
    lines = { "+also fires a shot behind you" },
    apply = function(s) s.backShot = true end,
  },
  {
    name = "Scavenger", rarity = "common",
    lines = { "+hits refund 1 ammo", "+hits cancel your reload" },
    apply = function(s) s.scavenger = s.scavenger + 1 end,
  },

  ---------------------------------------------------------------- Uncommon
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
    name = "Glass Cannon", rarity = "uncommon",
    lines = { "+100% damage", "-50% HP" },
    apply = function(s) s.damage = s.damage * 2; s.maxHp = s.maxHp * 0.5 end,
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
    apply = function(s) s.empower = true end,
  },
  {
    name = "Cloak", rarity = "uncommon", block = true,
    lines = { "+blocking turns you nearly invisible for 1.5s", "+homing can't track you" },
    apply = function(s) s.cloak = s.cloak + 1.5 end,
  },
  {
    name = "Trickster", rarity = "uncommon",
    lines = { "+1 bullet bounce", "+60% damage per bounce" },
    apply = function(s) s.bounces = s.bounces + 1; s.bounceDamage = s.bounceDamage + 0.6 end,
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
    name = "Overclock", rarity = "uncommon",
    lines = { "+fire rate ramps up to 3x while you hold fire" },
    apply = function(s) s.spinup = true end,
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
    name = "Repulsor", rarity = "uncommon",
    lines = { "+enemy bullets curve away from you" },
    apply = function(s) s.repel = s.repel + 1 end,
  },
  {
    name = "Underdog", rarity = "uncommon",
    lines = { "+20% damage per point you're behind" },
    apply = function(s) s.underdog = s.underdog + 1 end,
  },
  {
    name = "Reroll", rarity = "uncommon", special = "reroll",
    lines = { "Reroll these three cards" },
  },

  ---------------------------------------------------------------- Rare
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
    name = "Reflector", rarity = "rare", block = true,
    lines = { "+blocked bullets fly back at the shooter" },
    apply = function(s) s.reflect = true end,
  },
  {
    name = "Blink", rarity = "rare", block = true,
    lines = { "+blocking teleports you where you aim" },
    apply = function(s) s.blink = s.blink + 220 end,
  },
  {
    name = "Parry", rarity = "rare", block = true,
    lines = { "+blocking an attack instantly recharges your block" },
    apply = function(s) s.parry = true end,
  },
  {
    name = "Nova", rarity = "rare", block = true,
    lines = { "+blocking fires a ring of 8 bullets" },
    apply = function(s) s.blockNova = s.blockNova + 8 end,
  },
  {
    name = "Splitter", rarity = "rare",
    lines = { "+bullets split into 3 on their first wall hit" },
    apply = function(s) s.split = true end,
  },
  {
    name = "Sniper", rarity = "rare",
    lines = { "+damage grows the farther bullets fly", "+30% bullet speed", "-35% fire rate" },
    apply = function(s) s.distDamage = s.distDamage + 1; s.bulletSpeed = s.bulletSpeed * 1.3; s.fireDelay = s.fireDelay * 1.5 end,
  },
  {
    name = "Decay", rarity = "rare",
    lines = { "+damage you take is dealt slowly over 4s" },
    apply = function(s) s.decay = true end,
  },
  {
    name = "Ghost Bullets", rarity = "rare",
    lines = { "+bullets pass through walls", "-15% damage" },
    apply = function(s) s.ghost = true; s.damage = s.damage * 0.85 end,
  },
  {
    name = "Echo", rarity = "rare",
    lines = { "+every shot echoes 2 more times for free", "-30% damage" },
    apply = function(s) s.burst = s.burst + 2; s.damage = s.damage * 0.7 end,
  },
  {
    name = "Sticky Mines", rarity = "rare",
    lines = { "+spent bullets stick to walls as mines", "+mines explode near the enemy" },
    apply = function(s) s.sticky = true end,
  },
  {
    name = "Table Flip", rarity = "rare", special = "tableflip",
    lines = { "Rerolls every card you own", "Rarities stay the same" },
  },

  ---------------------------------------------------------------- Epic
  {
    name = "Phoenix", rarity = "epic",
    lines = { "+revive once per round at 50% HP" },
    apply = function(s) s.lives = s.lives + 1 end,
  },
  {
    name = "Orbiters", rarity = "epic",
    lines = { "+2 orbs circle you", "+orbs destroy enemy bullets", "+orbs damage the enemy" },
    apply = function(s) s.orbs = s.orbs + 2 end,
  },
  {
    name = "Black Hole", rarity = "epic",
    lines = { "+bullet impacts open a black hole", "+black holes pull the enemy in" },
    apply = function(s) s.blackhole = true end,
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
    lines = { "+enemy bullets near you slow to a crawl" },
    apply = function(s) s.stasis = true end,
  },

  ---------------------------------------------------------------- Legendary
  {
    name = "Laser", rarity = "legendary",
    lines = { "+your shots become instant laser beams", "+beams bounce off walls" },
    apply = function(s) s.laser = true end,
  },
  {
    name = "Shrine of Order", rarity = "legendary", special = "shrine",
    lines = { "All your cards of your most-held rarity become copies of one of them", "Card count stays the same" },
  },
}

-- Stable index per card, used to reference cards over the network.
for i, c in ipairs(Cards.list) do c.index = i end

local function rollRarity()
  local total = 0
  for _, r in ipairs(Cards.RARITIES) do total = total + r.weight end
  local x = love.math.random() * total
  for _, r in ipairs(Cards.RARITIES) do
    x = x - r.weight
    if x <= 0 then return r.id end
  end
  return "common"
end

-- Deal n distinct cards, rolling a rarity for each slot.
-- Table Flip / Shrine are only offered to a player who already owns cards.
function Cards.deal(n, player)
  local hand, used = {}, {}
  local attempts = 0
  while #hand < n and attempts < 500 do
    attempts = attempts + 1
    local rarity = rollRarity()
    local pool = {}
    for _, c in ipairs(Cards.list) do
      local useless = c.special and c.special ~= "reroll" and #player.cards == 0
      if c.rarity == rarity and not used[c] and not useless then pool[#pool + 1] = c end
    end
    if #pool > 0 then
      local c = pool[love.math.random(#pool)]
      used[c] = true
      hand[#hand + 1] = c
    end
  end
  return hand
end

-- A random keepable (non-special) card of the given rarity, preferring one other than `exclude`.
function Cards.randomOfRarity(rarity, exclude)
  local pool = {}
  for _, c in ipairs(Cards.list) do
    if c.rarity == rarity and not c.special and c ~= exclude then pool[#pool + 1] = c end
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

function Cards.shrine(player)
  local counts = {}
  for _, c in ipairs(player.cards) do counts[c.rarity] = (counts[c.rarity] or 0) + 1 end

  local candidates, bestN = {}, 0
  for _, r in ipairs(Cards.RARITIES) do
    local n = counts[r.id] or 0
    if n > bestN then
      candidates, bestN = { r.id }, n
    elseif n == bestN and n > 0 then
      table.insert(candidates, r.id)
    end
  end
  if bestN == 0 then return "The Shrine of Order found nothing to order" end
  local rarity = candidates[love.math.random(#candidates)]

  local owned = {}
  for _, c in ipairs(player.cards) do
    if c.rarity == rarity then owned[#owned + 1] = c end
  end
  local chosen = owned[love.math.random(#owned)]
  for i, c in ipairs(player.cards) do
    if c.rarity == rarity then player.cards[i] = chosen end
  end
  player:recompute()
  return string.format("SHRINE OF ORDER: %d %s card%s became %s",
    bestN, Cards.rarity[rarity].name, bestN == 1 and "" or "s", chosen.name)
end

return Cards
