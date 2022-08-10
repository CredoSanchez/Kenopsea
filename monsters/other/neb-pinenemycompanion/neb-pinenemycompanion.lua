require "/scripts/vec2.lua"

-- neb here, hiiii

function init()
  self.hostProjectile = config.getParameter("hostProjectile")
  self.hostVelocity = config.getParameter("hostVelocity")
  self.hostEntity = config.getParameter("hostEntity")
  self.pinnedTarget = config.getParameter("pinnedTarget")
  
  -- if is classed as boss or stationary in physics, dont move it, this is since some bosses need to be immobile
  local targetMovementSettings = world.callScriptedEntity(self.pinnedTarget, "mcontroller.baseParameters")
  for _, value in ipairs(targetMovementSettings.physicsEffectCategories) do
    if value == "boss" or value == "stationarymonster" then
      self.pinnedTarget = false
	end
  end
  
  -- if we successfully pinned the monster, stop it from moving
  if self.pinnedTarget then
    world.callScriptedEntity(self.pinnedTarget, "mcontroller.controlModifiers", {
	  facingSuppressed = true,
	  movementSuppressed = true
    })
  end
end

function update(dt)
  if self.hostProjectile and world.entityExists(self.hostProjectile) and self.pinnedTarget and world.entityExists(self.pinnedTarget) then
    mcontroller.setPosition(world.entityPosition(self.hostProjectile))
    updatePin(dt)
  else
    status.setResource("health", 0)
  end
end

function updatePin(dt)
  -- correct position so that we dont suffocate a monster by buring it in tiles
  local targetPosition = mcontroller.position()
  local polyToCheck = world.callScriptedEntity(self.pinnedTarget, "mcontroller.collisionPoly")
  local resolvedPolyPosition = world.resolvePolyCollision(polyToCheck, targetPosition, 5)
  -- if we could find a safe pos, update position, otherwise give up
  if resolvedPoly then
    targetPosition = resolvedPolyPosition
  end
  -- set position
  world.callScriptedEntity(self.pinnedTarget, "mcontroller.setPosition", targetPosition)
end

function uninit()
end

