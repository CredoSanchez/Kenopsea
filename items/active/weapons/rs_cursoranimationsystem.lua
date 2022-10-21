cursor = cursor or {}

function cursor.init(states)
  self.cursorStates = states
  cursor.initCursors()
  if self.cursorStates.idle then
	cursor.setCursorState("idle", true)
  end
end

function cursor.update(dt)
  if self.cursorStates and self.cursorState then
    local state = self.cursorStates[self.cursorState]
    self.animationTimer = (self.animationTimer + (dt * self.cursorAnimationRate * self.animationDirection)) % state.animationTime
    local currentFrame = math.ceil(self.animationTimer / state.animationTime * state.frames)
	local currentCursor = state.cursor:gsub("<frame>", currentFrame)
	world.debugText("%s", currentFrame, vec2.add(mcontroller.position(), activeItem.handPosition()), "red")
	for tagName, tagValue in pairs(self.cursorTags) do
	  currentCursor:gsub(tagName, tagValue)
	end
	activeItem.setCursor(currentCursor)
  end
  
end

function cursor.setCursorState(state, restart, direction)
  self.cursorState = state
  self.animationDirection = direction or 1
  if (restart and self.cursorState == state) or (self.cursorState ~= state) then
    self.animationTimer = 0
  end
  return not not self.cursorState
end

function cursor.cursorState()
  return self.cursorState
end

function cursor.setTag(tagName, tagValue)
  self.cursorTags[tagName] = tagValue
end

function cursor.setAnimationRate(rate)
  self.cursorAnimationRate = rate or 1
end

function cursor.initCursors()
  self.animationTimer = 0
  self.cursorAnimationRate = 1
  self.animationDirection = 1
  self.cursorTags = {}
  for cursor, cursorConfig in pairs(self.cursorStates) do
    cursorConfig.animationTime = cursorConfig.animationValue and config.getParameter(cursorConfig.animationValue) or cursorConfig.animationTime or 1
	cursorConfig.frames = cursorConfig.frames or 1
  end
end