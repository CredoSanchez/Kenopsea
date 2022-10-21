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
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAttack = getAltAbility()
  if secondaryAttack then
    self.weapon:addAbility(secondaryAttack)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
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