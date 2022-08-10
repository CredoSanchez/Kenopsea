require "/scripts/vec2.lua"
require "/scripts/status.lua"

-- neb here, hiiii againnn

function init()
  self.hostEntity = config.getParameter("hostEntity")
  self.searchRadius = config.getParameter("chainRadius", 10)
  self.chainStatusEffects = config.getParameter("chainStatusEffects", {})
  self.damageTransferFactor = config.getParameter("damageTransferFactor", 0.1)
  
  animator.setAnimationState("body", "activate")
  
  self.chainTemplate = config.getParameter("chainConfig", {})
  self.chainTargets = {}
  
  -- Listen to damage taken
  self.damageTaken = damageListener("damageTaken", function(notifications)
    for _, notification in pairs(notifications) do
      if notification.healthLost > 0 then
	    local newNotification = notification
		newNotification.damage = notification.damageDealt * self.damageTransferFactor
        for _, target in ipairs(self.chainTargets) do
		  world.callScriptedEntity(target, "status.applySelfDamageRequest", newNotification)
		end
      end
    end
  end)
  
  monster.setAnimationParameter("chains", config.getParameter("chains"))
end

function update(dt)
  if animator.animationState("body") == "active" and mcontroller.onGround() then
    self.damageTaken:update()
	self.chainTargets = {}
	local targets = world.entityQuery(mcontroller.position(), self.searchRadius + 2, {
      withoutEntityId = entity.id(),
      includedTypes = {"creature"},
      order = "nearest"
    })
	for _, target in ipairs(targets) do
	  if world.entityCanDamage(self.hostEntity, target) then
		table.insert(self.chainTargets, target)
	  end
	end
	updateChains(self.chainTargets)
  end
end

function updateChains(targets)
  local chains = {}
  for _, target in ipairs(targets) do
    --Chains
    local newChain = sb.jsonMerge(self.chainTemplate, {})
	newChain.endPosition = world.entityMouthPosition(target)
	newChain.startPosition = vec2.add(mcontroller.position(), self.chainTemplate.startOffset)
	table.insert(chains, newChain)
    
	--Effects
	for _, effect in ipairs(self.chainStatusEffects) do
	  world.sendEntityMessage(target, "applyStatusEffect", effect)
	end
	
	--Binding
	local mag = world.magnitude(world.entityPosition(target), mcontroller.position())
	if mag > self.searchRadius then
	  local targetDirection = vec2.norm(world.distance(world.entityPosition(target), mcontroller.position()))
	  local targetPos = vec2.add(mcontroller.position(), vec2.mul(targetDirection, self.searchRadius))
	  world.callScriptedEntity(target, "mcontroller.setPosition", targetPos)
	end
  end
  monster.setAnimationParameter("chains", chains)
end

function uninit()
end

