local Stack = require("stack")
local Evaluator = require("evaluator")
local flux = require("flux")
local cron = require("cron")

function love.load()
  keyboard_input = {}
  fontSize = 60
  font = love.graphics.newFont(fontSize)
  typingFont = love.graphics.newFont(16)
  renderList = {}
  currentStepIndex = 1
  animationDuration = 0.2
  camX, camY = 0, 0
  camX0, camY0 = 0, 0
  mouseX0, mouseY0 = 0, 0
  mouseDown = false
  camZoom = 1

  love.window.setTitle("Bruh")

  reset("5+5*10")
end

function love.textinput(key)
  if Evaluator.IsDigit(key) or Evaluator.IsOperator(key) then
    table.insert(keyboard_input, key)
  end
end

function love.keypressed(key)
  if key == "return" or key == "kpenter" then
    local expression = table.concat(keyboard_input, "")
    reset(expression)
    keyboard_input = {}
  elseif key == "backspace" then
    table.remove(keyboard_input, #keyboard_input)
  elseif key == "right" then
    nextStep(1)
  elseif key == "left" then
    nextStep(-1)
  end
end

crons = {}

function love.update(dt)
  flux.update(dt)
  for _, c in pairs(crons) do c:update(dt) end

  if not mouseDown then
    mouseX0, mouseY0 = love.mouse.getPosition()
    camX0, camY0 = camX, camY
  end

  mouseDown = love.mouse.isDown(1)

  if mouseDown then
    local mouseX, mouseY = love.mouse.getPosition()
    local dMouseX, dMouseY = mouseX - mouseX0, mouseY - mouseY0
    camX, camY = camX0 - dMouseX / camZoom, camY0 - dMouseY / camZoom
  end
end

function mouseToWorld()
  local mouseX, mouseY = love.mouse.getPosition()
  local mouseWorldX = mouseX / camZoom + camX
  local mouseWorldY = mouseY / camZoom + camY
  return mouseWorldX, mouseWorldY
end

function love.mousepressed(x, y, btn)
  if btn == 2 then
    camX = 0
    camY = 0
    camZoom = 1
  end
end

function love.wheelmoved(x, y)
  local wMouseX0, wMouseY0 = mouseToWorld()

  if y > 0 then
    camZoom = camZoom + 0.1
  elseif y < 0 then
    camZoom = camZoom - 0.1
    if camZoom < 0.1 then
      camZoom = 0.1
    end
  end

  local wMouseX, wMouseY = mouseToWorld()
  local dx, dy = wMouseX -wMouseX0, wMouseY - wMouseY0

  camX, camY = camX - dx, camY - dy
end

function makeRenderListForStep(step)
  local cursor = 0
  local renderL = {}
  for _, token in pairs(step) do
    local renderElement = {
      x = cursor,
      y = 0,
      opacity = 1,
      token = token
    }
    table.insert(
      renderL,
      renderElement
    )
    cursor = cursor + font:getWidth(token.value)
  end

  return renderL
end

function determineChanges(previous, next)
  local changes = {
    added = {},
    removed = {},
    moved = {}
  }

  local lookupNext = {}

  for i, element in pairs(next) do
    lookupNext[element.token.id] = {
      index = i,
      element = element
    }
  end

  for i, element in pairs(previous) do
    --If in A but not in B -> removed
    local match = lookupNext[element.token.id]
    if match == nil then
      table.insert(changes.removed, i)
    else --In A and in B (has a match) -> moved
      table.insert(changes.moved, {
        index = i,
        location = {
          x = match.element.x,
          y = match.element.y
        }
      })
      
      --Remove the match
      lookupNext[element.token.id] = nil
    end
  end

  --The rest in the next render list are added elements
  for _, match in pairs(lookupNext) do
    table.insert(changes.added, match.index)
  end

  return changes
end

function reset(expr)
  steps = GetStepByStepInfix(expr)
  currentStepIndex = 1
  nextStep(0)
end

local skipAllowed = true

function nextStep(delta)
  local currentStep = steps[currentStepIndex]
  local nextStep = steps[currentStepIndex + delta]

  if nextStep == nil or not skipAllowed then
    return
  end

  local nextStepRenderList = makeRenderListForStep(nextStep)

  if delta == 0 then
    renderList = nextStepRenderList
    return
  end

  skipAllowed = false
  
  local changes = determineChanges(renderList, nextStepRenderList)

  --Do animation
  for _, index in pairs(changes.removed) do
    flux.to(renderList[index], animationDuration, { opacity = 0, y = 10 })
  end

  --After removing animation is done
  local c1 = cron.after(animationDuration, function ()
    for _, moved in pairs(changes.moved) do
      flux
        .to(renderList[moved.index], animationDuration, { x = moved.location.x, y = moved.location.y })
    end
  end)

  --After moving animation is done
  local c2 = cron.after(animationDuration * 2, function ()
    skipAllowed = true

    for _, added in pairs(changes.added) do
      renderList = nextStepRenderList
      renderList[added].opacity = 0
      renderList[added].y = -10
      flux.to(renderList[added], animationDuration, { opacity = 1, y = 0 })
    end
  end)

  table.insert(crons, c1)
  table.insert(crons, c2)

  currentStepIndex = currentStepIndex + delta
end

function drawInput()
  love.graphics.setFont(typingFont)
  love.graphics.setColor(1, 1, 1, 1)

  local sw, sh = love.graphics.getDimensions()
  local keyboard_input_string = table.concat(keyboard_input, "")
  local w, h = typingFont:getWidth(keyboard_input_string), 16
  love.graphics.print(keyboard_input_string, sw - w, sh - h)
end

function drawRenderList()
  love.graphics.setFont(font)
  local sw, sh = love.graphics.getDimensions()

  love.graphics.translate(20, sh / 2 - fontSize / 2)

  for i, renderElement in pairs(renderList) do
    local text = tostring(renderElement.token.value)
    local o = renderElement.opacity
    love.graphics.setColor(o, o, o, o)

    love.graphics.print(text, renderElement.x, renderElement.y)
  end
end

function love.draw()
  love.graphics.scale(camZoom)
  love.graphics.translate(-camX, -camY)

  drawRenderList()

  local w, h = love.graphics.getDimensions()
  local x, y = mouseToWorld()

  love.graphics.origin()
  love.graphics.scale(0.25)

  love.graphics.setColor(1, 1, 1, 0.2)
  love.graphics.rectangle("line", 0, 0, w, h)

  love.graphics.setColor(1, 0, 0, 1)
  love.graphics.rectangle("line", camX, camY, w / camZoom, h / camZoom)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", x, y, 5)

  drawRenderList()

  love.graphics.origin()
  drawInput()
end

