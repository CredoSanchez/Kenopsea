require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.retainDamage = config.getParameter("retainStickingDamage", false)
  
  self.pinnedTarget = nil
  self.stuckToTarget = false
  self.stuckToGround = false
  self.hasActioned = false
  
  message.setHandler("kill", function()
	projectile.die()
  end)
end

function update(dt)
  --While our target lives, make the target follow the projectile
  if self.pinnedTarget then
    if not world.entityExists(self.pinnedTarget) then
	  self.pinnedTarget = nil
    end
  end
  
  if self.hasStruckTarget and not self.retainDamage then
    projectile.setPower(0)
  end
end

function hit(entityId)
  if not self.stuckToGround and not self.pinnedTarget then
    self.pinnedTarget = entityId
    self.stuckToTarget = true
    self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.pinnedTarget))
	
	local params = {}
    params.hostProjectile = entity.id()
	params.hostEntity = projectile.sourceEntity()
	params.hostVelocity = mcontroller.velocity()
	params.pinnedTarget = self.pinnedTarget
	
    if not self.pinEnemyCompanion then
      self.pinEnemyCompanion = true
	  world.spawnMonster(
	    "neb-pinenemycompanion",
	    mcontroller.position(),
	    params
	  )
	end
  end
  self.hasStruckTarget = true
end

