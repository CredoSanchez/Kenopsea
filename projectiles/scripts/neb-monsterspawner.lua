function update(dt)
  spawnMonster()
  projectile.die()
end

function spawnMonster()
  if not self.hasSpawnedMonster then	
	local params = {}
    params.hostProjectile = entity.id()
	params.hostEntity = projectile.sourceEntity()
	
	world.spawnMonster(
	  config.getParameter("monsterToSpawn", "poptop"),
	  mcontroller.position(),
	  params
	)
  end
  self.hasSpawnedMonster = true
end

