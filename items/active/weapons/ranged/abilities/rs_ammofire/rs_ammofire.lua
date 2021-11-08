require "/scripts/util.lua"
require "/scripts/interp.lua"

--By nebby

-- Base gun fire ability
RSAmmoFire = WeaponAbility:new()

function RSAmmoFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	animator.stopAllSounds("reloadLoop")
  end
  
  self.currentAmmo = config.getParameter("ammoCount", self.maxAmmo)
  
  animator.setAnimationState("gun", "idle")
end

function RSAmmoFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  animator.setParticleEmitterActive("heavyReady", self:isShotHeavy(self.maxAmmo - self.currentAmmo + 1))

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
	and self.currentAmmo > 0 then

    if self.fireType == "auto" then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
  
  --Reload automatically if clip is empty
  if self.currentAmmo == 0 and not self.weapon.currentAbility then
	if self.stances.preReloadTwirl then
	  self:setState(self.preReloadTwirl)
	else
	  self:setState(self.reload)
	end
  end
  
  --Manual reload
  if self.fireMode == "alt" and self.currentAmmo ~= self.maxAmmo and not self.weapon.currentAbility and not self.disableManualReload then
	if self.stances.preReloadTwirl then
	  self:setState(self.preReloadTwirl)
	else
	  self:setState(self.reload)
	end
  end
end

function RSAmmoFire:auto()
  self.weapon:setStance(self.stances.fire)

  local projectileIsHeavy = self:isShotHeavy(self.maxAmmo - self.currentAmmo + 1)

  self:fireProjectile(projectileIsHeavy)
  self:muzzleFlash(projectileIsHeavy)
  
  --Remove ammo from the magazine, and cycle the weapon if needed
  self.currentAmmo = self.currentAmmo - 1
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function RSAmmoFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 do
    local projectileIsHeavy = self:isShotHeavy(self.maxAmmo - self.currentAmmo + 1)

    self:fireProjectile(projectileIsHeavy)
    self:muzzleFlash(projectileIsHeavy)
    
	shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end
  
  --Remove ammo from the magazine, and cycle the weapon if needed
  self.currentAmmo = self.currentAmmo - 1
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function RSAmmoFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function RSAmmoFire:reload()
  self.weapon:setStance(self.stances.reload)
  self.weapon:updateAim()

  --Start the reload animation, sound and effects
  animator.setAnimationState("gun", "reload")
  animator.playSound("reloadLoop", -1)
  animator.burstParticleEmitter("reload")
  
  local timer = 0
  util.wait(self.stances.reload.duration, function()
	--FRONT ARM
	local frontArm = self.stances.reload.frontArmFrame or "rotation"
	if self.stances.reload.frontArmFrameSequence then
	  --Run through each sequence step and update arm frame accordingly
	  for i,step in ipairs(self.stances.reload.frontArmFrameSequence) do
		if timer > step[1] then
		  frontArm = step[2]
		end
	  end
	  self.stances.reload.frontArmFrame = frontArm
	  self.weapon:updateAim()
	end
	
	--BACK ARM
	local backArm = self.stances.reload.backArmFrame or "rotation"
	if self.stances.reload.backArmFrameSequence then
	  --Run through each sequence step and update arm frame accordingly
	  for i,step in ipairs(self.stances.reload.backArmFrameSequence) do
		if timer > step[1] then
		  backArm = step[2]
		end
	  end
	  self.stances.reload.backArmFrame = backArm
	  self.weapon:updateAim()
	end

	timer = timer + self.dt
  end)
  
  --Finish the reload animation, sound and effects, and update ammo values
  animator.playSound("reload")
  animator.stopAllSounds("reloadLoop")
  self.currentAmmo = self.maxAmmo
  activeItem.setInstanceValue("ammoCount", self.maxAmmo)
  
  if self.stances.reloadTwirl then
	self:setState(self.reloadTwirl)
  elseif self.readyTime then
	self.cooldownTimer = self.readyTime
  end
end

function RSAmmoFire:muzzleFlash(heavy)
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setPartTag("muzzleFlash", "type", heavy and "heavy" or "")
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire" .. (heavy and "Heavy" or ""))
  
  --Optional firing animations
  if self.fireAnimation == true then
	animator.setAnimationState("gun", "fire")
  end

  animator.setLightActive("muzzleFlash", true)
end

function RSAmmoFire:fireProjectile(heavyShot, projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot() * (heavyShot and self.heavyDamageMultiplier or 1)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  
  if not projectileType then
    projectileType = self.projectileType
  end
  
  if heavyShot then
    projectileCount = 1
	projectileType = self.heavyProjectileType
  end
  
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

--Determine if the shot is a heavy shot
function RSAmmoFire:isShotHeavy(currentShot)
  local shotIsHeavy = false
  for _, shot in ipairs(self.shotIntervals) do
    if currentShot == shot then
	  shotIsHeavy = true
	end
  end
  return shotIsHeavy
end

function RSAmmoFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function RSAmmoFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function RSAmmoFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function RSAmmoFire:uninit()
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)
end