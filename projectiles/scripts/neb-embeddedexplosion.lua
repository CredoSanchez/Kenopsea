require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.searchDistance = config.getParameter("searchRadius")
  self.stickingTarget = nil
  self.stickingOffset = {0,0}
  self.stuckToTarget = false
  self.stuckToGround = false
  
  self.detonateSearchDistance = config.getParameter("detonateSearchDistance", 15)
  self.actionOnDetonate = config.getParameter("actionOnDetonate")
  message.setHandler("detonateProjectile", function(_, _)
	detonate()
  end)
end

function update(dt)
  local targets = {}
  
  --Look for a target to stick to
  if not self.stickingTarget then
	local projectileLengthVector = vec2.norm(mcontroller.velocity())
	self.stuckToGround = world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), projectileLengthVector))
	targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
	  withoutEntityId = projectile.sourceEntity(),
	  includedTypes = {"npc","monster"},
	  order = "nearest"
	})
  end

  --If targets were found, set tracking info to the closest entity, unless we were already stuck in the ground
  if #targets > 0 and not self.stuckToGround then
	if world.entityExists(targets[1]) then
	  self.stickingTarget = targets[1]
	  self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
	  mcontroller.setVelocity({0,0})
	  self.stuckToTarget = true
	  if config.getParameter("stickToTargetTime") then
		projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
	  end
	end
  end
  
  --While our target lives, make the projectile follow the target
  if self.stickingTarget and world.entityExists(self.stickingTarget) then
	local targetStickingPosition = vec2.add(world.entityPosition(self.stickingTarget), self.stickingOffset)
	mcontroller.setPosition(targetStickingPosition)
	local stickingVelocity = vec2.mul(self.stickingOffset, -1)
	mcontroller.setVelocity(stickingVelocity)
  else
	self.stickingTarget = nil
  end
  
  --If we were stuck to a target, but got unstuck, kill the projectile
  if self.stuckToTarget and not self.stickingTarget then
	projectile.die()
  end
  
  if self.stuckToGround then
	if config.getParameter("proximitySearchRadius") then
	  local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
		withoutEntityId = projectile.sourceEntity(),
		includedTypes = {"projectile"},
		order = "nearest"
	  })

	  for _, target in ipairs(targets) do
		if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) then
		  projectile.die()
		  return
		end
	  end
	end
  end
  
  --Find other projectiles
  local explodableProjectiles = world.entityQuery(mcontroller.position(), self.detonateSearchDistance, {
	includedTypes = {"projectile"},
	order = "nearest",
	callScript = "canExplode",
    callScriptArgs = {},
    callScriptResult = true
  })
  
  if #explodableProjectiles >= config.getParameter("requiredCountToDetonate", 5) then
	for _, target in ipairs(explodableProjectiles) do
	  if entity.entityInSight(target) then
		world.sendEntityMessage(target, "detonateProjectile")
	  end
	end
  end
end

function canExplode()
  return self.stickingTarget ~= nil
end

function detonate()
  for _, action in pairs(self.actionOnDetonate) do
	projectile.processAction(action)
	projectile.die()
  end
end
