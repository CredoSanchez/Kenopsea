require "/scripts/util.lua"

function initShip()
  self.moveSpeed = config.getParameter("moveSpeed")
  self.airForce = config.getParameter("airForce")
  
  self.minHeight = config.getParameter("minHeight")
  self.maxHeight = config.getParameter("maxHeight")
  self.height = 0
  
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")

  self.protection = config.getParameter("protection")
  storage.health = storage.health or config.getParameter("health")

  self.driving = false
  self.lastDriver = nil
  
  self.facingDirection = 1
end

function updateShip(dt, driver, moveDir)
  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("explode")
    vehicle.destroy()
  end

  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  if driver then
    if self.lastDriver == nil then
      animator.playSound("engineStart")
      animator.setAnimationState("thrust", "on")
    end

    if driver == 0 then
      vehicle.setDamageTeam({type = "passive"})
    else
      vehicle.setDamageTeam(world.entityDamageTeam(driver))
    end
    mcontroller.applyParameters(self.occupiedMovementSettings)
    vehicle.setInteractive(false)
  else
    vehicle.setDamageTeam({type = "passive"})
    animator.setAnimationState("thrust", "off")
    mcontroller.applyParameters(self.movementSettings)
    vehicle.setInteractive(true)
  end
  self.lastDriver = driver

  local driving = vec2.mag(moveDir) > 0.0
  if driving and not self.driving then
    animator.playSound("engineLoop", -1)
  elseif not driving then
    animator.stopAllSounds("engineLoop", 0.5)
  end
  self.driving = driving

  if moveDir[1] ~= 0 then
    self.facingDirection = util.toDirection(moveDir[1])
    animator.setFlipped(moveDir[1] < 0)
  end
  
  animator.resetTransformationGroup("rotation")

  if driver then
    local start = mcontroller.position()
    local bottom = vec2.add(start, {0, -self.maxHeight * 2.0})
    local ground
    for xOffset = -5, 5 do
      local findGround = world.collisionBlocksAlongLine(vec2.add(start, {xOffset, 0}), vec2.add(bottom, {xOffset, 0}))[1]
      if findGround and (not ground or findGround[2] > ground[2]) then
        ground = findGround
      end
    end

    local groundDist = self.maxHeight * 2.0
    if ground then
      groundDist = world.distance(start, vec2.add(ground, {0, 1}))[2]
    end
    if groundDist > self.maxHeight then
      moveDir[2] = math.min((self.maxHeight - groundDist) / self.maxHeight, moveDir[2])
    end
    if groundDist < self.minHeight then
      moveDir[2] = math.max((self.minHeight - groundDist) / self.minHeight, moveDir[2])
    end
    self.height = groundDist

    moveDir = vec2.norm(moveDir)
    mcontroller.approachVelocity(vec2.mul(moveDir, self.moveSpeed), self.airForce)

    local tilt = mcontroller.yVelocity() / self.moveSpeed * 0.5
    mcontroller.setRotation(tilt * util.toDirection(moveDir[1]))
    animator.rotateTransformationGroup("rotation", tilt)
	
  else
    mcontroller.rotate(-mcontroller.rotation() * dt)
  end
end

function shipHeight()
  return self.height
end

function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end

  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = "robotic",
    killed = storage.health <= 0
  }}
end