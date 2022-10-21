require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  if config.getParameter("passiveStatusEffects") then
    self.tagGroup = ("rs_" .. config.getParameter("itemName") .. activeItem.hand())
    status.addPersistentEffects(self.tagGroup, config.getParameter("passiveStatusEffects"))
  end
  
  if config.getParameter("cursorStates") then
	require("/items/active/weapons/rs_cursoranimationsystem.lua")
	cursor.init(config.getParameter("cursorStates"))
  else
    activeItem.setCursor(config.getParameter("cursor", "/cursors/pointer.cursor"))
  end
  
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAbility = getAltAbility(self.weapon.elementalType)
  if secondaryAbility then
    self.weapon:addAbility(secondaryAbility)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
  if cursor then cursor.update(dt) end
  
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset)), "red")
end

function uninit()
  if config.getParameter("passiveStatusEffects") then
    status.clearPersistentEffects(self.tagGroup)
    if config.getParameter("statusEffectsLingerOnUnequip") then
	  status.addEphemeralEffects(config.getParameter("passiveStatusEffects"), activeItem.ownerEntityId())
	end
  end

  self.weapon:uninit()
end