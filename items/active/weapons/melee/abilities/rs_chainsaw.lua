require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

RSChainsawCharge = WeaponAbility:new()

function RSChainsawCharge:init()
  self:reset()
  self.energyUsage = self.energyUsage or 0
  
  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function RSChainsawCharge:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  animator.setParticleEmitterActive("miningSparks", self.damagingTiles)

  if self.weapon.currentAbility == nil
      and self.fireMode == (self.activatingFireMode or self.abilitySlot)
      and not status.resourceLocked("energy") then

    self:setState(self.windup)
  end
end

function RSChainsawCharge:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.playSound("windup")

  animator.setAnimationState("chainsaw", (self.activatingFireMode or self.abilitySlot) .. "Active2")
  animator.setAnimationState("energy", (self.activatingFireMode or self.abilitySlot) .. "Windup1")
  util.wait(self.stances.windup.duration / 2)
  animator.setAnimationState("energy", (self.activatingFireMode or self.abilitySlot) .. "Windup2")
  util.wait(self.stances.windup.duration / 2)

  self:setState(self.charge)
end

function RSChainsawCharge:charge()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("energy", (self.activatingFireMode or self.abilitySlot) .. "Active2")
  animator.setParticleEmitterActive("charge", true)

  self.tileDamageTimer = 0

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", self.energyUsage * self.dt) do
    self.weapon:updateAim()
	
	if not self.holdLoopPlaying then
	  if animator.hasSound("holdLoop") then
		animator.playSound("holdLoop", -1)
		self.holdLoopPlaying = true
	  end
	  if animator.hasSound("damageLoop") then
		animator.playSound("damageLoop", -1)
		self.holdLoopPlaying = true
	  end
	else
	  if animator.hasSound("holdLoop") then
		if self.damagingTiles and animator.hasSound("damageLoop") then
		  animator.setSoundVolume("holdLoop", 0, 0)
		  animator.setSoundVolume("damageLoop", 1, 0)
		else
		  animator.setSoundVolume("holdLoop", 1, 0)
		  if animator.hasSound("damageLoop") then
			animator.setSoundVolume("damageLoop", 0, 0)
		  end
		end
	  end
	end

    local damageArea = partDamageArea("chainsawEnergy")
    self.weapon:setDamage(self.damageConfig, damageArea, self.damageTimeout)

    self:damageTiles()

    coroutine.yield()
  end

  animator.setParticleEmitterActive("charge", false)

  self:setState(self.winddown)
end

function RSChainsawCharge:damageTiles()
  local pos = mcontroller.position()
  local tipPosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("chainsawEnergy", "tipPosition")))
  local sourcePosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("chainsawEnergy", "sourcePosition")))
  local miningPositions = {sourcePosition}
  local tileDamage = self.tileDamagePerSecond * self.dt
  
  self.damagingTiles = false
  for i = 1, world.magnitude(tipPosition, sourcePosition) do
	local distanceFactor = 1 / world.magnitude(tipPosition, sourcePosition)
	local position = vec2.add(vec2.mul(world.distance(tipPosition, sourcePosition), (distanceFactor * i)), sourcePosition)
	table.insert(miningPositions, position)
  end
  
  if self.damageForeground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "foreground", sourcePosition, "plantish", tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
  
  if self.damageBackground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "background", sourcePosition, "plantish", tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
end

function RSChainsawCharge:winddown()
  self.weapon:setStance(self.stances.winddown)
  self.weapon:updateAim()

  if animator.hasSound("holdLoop") then
	animator.stopAllSounds("holdLoop")
  end
  if animator.hasSound("damageLoop") then
	animator.stopAllSounds("damageLoop")
  end
  
  self.damagingTiles = false
  self.holdLoopPlaying = false
  
  animator.playSound("winddown")

  animator.setAnimationState("energy", (self.activatingFireMode or self.abilitySlot) .. "Windup2")
  util.wait(self.stances.winddown.duration / 2)
  animator.setAnimationState("energy", (self.activatingFireMode or self.abilitySlot) .. "Windup1")
  util.wait(self.stances.winddown.duration / 2)
end

function RSChainsawCharge:reset()
  self.weapon:setDamage()
  
  animator.setAnimationState("chainsaw", "idle")
  animator.setAnimationState("energy", "idle")
  if animator.hasSound("holdLoop") then
	animator.stopAllSounds("holdLoop")
  end
  if animator.hasSound("damageLoop") then
	animator.stopAllSounds("damageLoop")
  end
  
  self.damagingTiles = false
  self.holdLoopPlaying = false
  animator.setParticleEmitterActive("miningSparks", false)
end

function RSChainsawCharge:uninit()
  self:reset()
end