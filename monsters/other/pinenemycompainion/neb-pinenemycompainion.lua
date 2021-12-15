require "/scripts/starforge-util.lua"
require "/scripts/vec2.lua"

function init()
  self.hostProjectile = config.getParameter("hostProjectile")
  self.hostVelocity = config.getParameter("hostVelocity")
  self.hostEntity = config.getParameter("hostEntity")
  self.pinnedTarget = config.getParameter("pinnedTarget")
  
  if self.pinnedTarget then
    world.callScriptedEntity(self.pinnedTarget, "mcontroller.controlModifiers", {
	  facingSuppressed = true,
	  movementSuppressed = true
    })
  end
end

function update(dt)
  if self.hostProjectile and world.entityExists(self.hostProjectile) then
    mcontroller.setPosition(world.entityPosition(self.hostProjectile))
    if self.pinnedTarget and world.entityExists(self.pinnedTarget) then
      updatePin(dt)
    end
  else
    status.setResource("health", 0)
  end
end

function updatePin(dt)
  world.callScriptedEntity(self.pinnedTarget, "mcontroller.setPosition", mcontroller.position())
end

function uninit()
end

