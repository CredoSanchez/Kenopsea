require "/scripts/interp.lua"
require "/scripts/status.lua"

-- Melee primary ability
RSMeleeCombo = WeaponAbility:new()

function RSMeleeCombo:init()
  self.comboStep = 1
  animator.setGlobalTag("comboDirectives", "")

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns(false)

  self.weapon:setStance(self.stances.idle)
  
  self.shieldHealth = 1000

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function RSMeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function RSMeleeCombo:windup()
  local stance = self.stances["windup"..self.comboStep]
  
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0
  
  local chargeTimer = self.chargeTime
  if self.chargeTime and self.comboStep == 1 then
    local fullyCharged = false
	local flashTimer = 0
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      if chargeTimer > 0 then
	    chargeTimer = math.max(0, chargeTimer - self.dt)
	  end
      if flashTimer > 0 then
	    flashTimer = math.max(0, flashTimer - self.dt)
		if flashTimer == 0 then
		  animator.setGlobalTag("bladeDirectives", "")
		end
	  end
	  
	  --Prevent energy regen while charging
	  status.setResourcePercentage("energyRegenBlock", 0.6)
	
	  --Enable walk while charging
	  if self.walkWhileCharging == true then
        mcontroller.controlModifiers({runningSuppressed=true})
	  end
	  
	  if not fullyCharged and chargeTimer == 0 then
		if status.overConsumeResource("energy", self.energyUsage) then
		  fullyCharged = true
		  animator.playSound("readyBlade")
		  flashTimer = self.flashTime
		  animator.setGlobalTag("bladeDirectives", self.chargeDirectives or "")
		end
	  end
      coroutine.yield()
    end
  elseif stance.endWeaponRotation then
    --Smoothly windup
    local progress = 0
    util.wait(stance.duration, function()
      progress = math.min(stance.duration, progress + self.dt)
      local progressRatio = math.sin(progress / stance.duration * 1.57)
	
	  local from = stance.weaponOffset or {0,0}
      local to = stance.endWeaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {stance.weaponRotation, stance.endWeaponRotation}))
      self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {stance.armRotation, stance.endArmRotation}))
    end)
  else
    util.wait(stance.duration)
  end  
  animator.setGlobalTag("bladeDirectives", "")

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash, chargeTimer == 0)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function RSMeleeCombo:wait(stance)  
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  animator.setGlobalTag("comboDirectives", "")
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function RSMeleeCombo:preslash(charged)
  local stance = self.stances["preslash"..self.comboStep]
  
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(charged and self.chargedFire or self.fire)
end

function RSMeleeCombo:chargedFire()
  local foundProjectiles = {}
  local hit = false
  
  --Seting up the damage listener for actions on shield hit
  self.damageListener = damageListener("damageTaken", function(notifications)
	--Optionally spawn a parry projectile when the shield is hit
	for _, notification in pairs(notifications) do
	  if notification.hitType == "ShieldHit" then
		--Fire a projectile when the shield is hit
		if #self.reflectedProjectiles > 0 and not hit then
		  animator.playSound("parry")
	      hit = true
		  status.overConsumeResource("energy", status.resourceMax("energy"))
		end
		
		--Projectile parameters
		for _, projectileConfig in ipairs(self.reflectedProjectiles) do
		  local params = copy(projectileConfig)
		  --params.power = params.power * config.getParameter("damageLevelMultiplier")
		  params.powerMultiplier = activeItem.ownerPowerMultiplier()
		  params.speed = params.speed * 1.25
		  
		  --Projectile spawn code
		  if not world.pointTileCollision(mcontroller.position()) then
		    for i = 1, self.projectileCount or 1 do
			  local aimAngle = math.atan(params.position[2] - activeItem.ownerAimPosition()[2], params.position[1] - activeItem.ownerAimPosition()[1])
			  local aimVec = vec2.rotate({1,0}, -aimAngle)
			  aimVec[1] = aimVec[1] * -1
		  	  world.spawnProjectile(projectileConfig.projectileName, params.position, activeItem.ownerEntityId(), aimVec, false, params)
		    end
		  end
		end
		
		return
	  end
	end
  end)
  
  --Rendering the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = self.shieldHealth}})
  
  local stance = self.stances["chargeFire"]
  
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = "chargeFire"
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  self.reflectedProjectiles = {}
  local populatedProjectiles = false
  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
	
	self.damageListener:update()
	local shieldPoly = animator.partPoly("swoosh", "parryPoly")
    activeItem.setItemShieldPolys({shieldPoly})
	
	foundProjectiles = world.entityQuery(mcontroller.position(), 7, 
	  {
		withoutEntityId = entity.id(),
		includedTypes = {"projectile"},
		order = "nearest"
	  }
	)
	if #foundProjectiles > 0 and not populatedProjectiles then
	  populatedProjectiles = true
	  for _, projectile in ipairs(foundProjectiles) do
	    local projectileName = world.entityName(projectile)
		local projectileConfig = root.projectileConfig(projectileName)
		projectileConfig.position = world.entityPosition(projectile)
		if not projectileConfig.piercing then
		  table.insert(self.reflectedProjectiles, projectileConfig)
	    end
	  end
	end
	
    self.weapon:setDamage(self.chargeAttackConfig, damageArea)
  end)
  
  activeItem.setItemShieldPolys({})
  status.clearPersistentEffects("broadswordParry")

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait, self.stances["chargeFire"])
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    animator.setGlobalTag("comboDirectives", "")
    self.comboStep = 1
  end
end

-- State: fire
function RSMeleeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]
  
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait, self.stances["wait"..(self.comboStep - 1)])
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    animator.setGlobalTag("comboDirectives", "")
    self.comboStep = 1
  end
end

function RSMeleeCombo:shouldActivate()
  if self.cooldownTimer == 0 then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function RSMeleeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function RSMeleeCombo:computeDamageAndCooldowns(charged)
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), copy(self.stepDamageConfig[i]))
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
  
  --Charged attack damage
  self.chargeAttackConfig = copy(self.chargedDamageConfig)
  local damageFactor = self.chargeAttackConfig.baseDamageFactor
  self.chargeAttackConfig.baseDamage = damageFactor * self.baseDps * self.fireTime
end

function RSMeleeCombo:uninit()
  activeItem.setItemShieldPolys({})
  status.clearPersistentEffects("broadswordParry")
  self.weapon:setDamage()
end
