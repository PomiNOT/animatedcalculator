local TOKEN_TYPE = {
  Add = 0,
  Subtract = 1,
  Multiply = 2,
  Divide = 3,
  LeftParenth = 4,
  RightParenth = 5,
  Number = 6
}

local PRIORITY = {
  [TOKEN_TYPE.Add] = 0,
  [TOKEN_TYPE.Subtract] = 0,
  [TOKEN_TYPE.Multiply] = 1,
  [TOKEN_TYPE.Divide] = 1
}

local operators = {
  ["+"] = TOKEN_TYPE.Add,
  ["-"] = TOKEN_TYPE.Subtract,
  ["*"] = TOKEN_TYPE.Multiply,
  ["/"] = TOKEN_TYPE.Divide
}

local otherOperators = {
  ["("] = TOKEN_TYPE.LeftParenth,
  [")"] = TOKEN_TYPE.RightParenth
}

function Map(array, func)
  local ret = {}
  for _, element in pairs(array) do
    table.insert(ret, func(element))
  end
  return ret
end

function DeepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
          copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
      end
      setmetatable(copy, DeepCopy(getmetatable(orig)))
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end


function MakeToken(element, index)
  if IsOperator(element) or IsParenth(element) then
    return {
      id = love.math.random(),
      index = index,
      type = operators[element],
      value = element
    }
  else
    return {
      id = love.math.random(),
      index = index,
      type = TOKEN_TYPE.Number,
      value = tonumber(element)
    }
  end
end

function IsOperator(char)
  return operators[char] ~= nil
end

function IsParenth(char)
  return otherOperators[char] ~= nil
end

function IsDigit(char)
  return '0' <= char and char <= '9'
end

function Tokenize(infixString)
  local element = {}
  local elementIndex = 1
  local tokens = {}
  for i=1,#infixString do
    local c = infixString:sub(i, i)
    local nextC = infixString:sub(i+1, i+1)

    table.insert(element, c)

    if 
      IsDigit(c) and not IsDigit(nextC)
      or not IsDigit(c) and IsDigit(nextC)
      or not IsDigit(nextC)
    then
      table.insert(tokens, MakeToken(table.concat(element, ""), elementIndex))
      elementIndex = elementIndex + 1
      element = {}
    end
  end

  return tokens
end

function InfixToPostfix(infixTokens)
  local postfixStack = Stack.new()
  local operatorsStack = Stack.new()

  for _, token in pairs(infixTokens) do
    if token.type == TOKEN_TYPE.Number then
      postfixStack:push(token)
    elseif IsOperator(token.value) then
      while 
        operatorsStack:top() ~= nil and
        PRIORITY[operatorsStack:top().type] >= PRIORITY[token.type]
      do
        postfixStack:push(operatorsStack:pop())
      end

      operatorsStack:push(token)
    end
  end

  while operatorsStack:top() ~= nil do postfixStack:push(operatorsStack:pop()) end

  return postfixStack.stack
end

function Evaluate(postfixTokens)
  local evalStack = Stack.new()
  local steps = {}

  for _, token in pairs(postfixTokens) do
    if token.type == TOKEN_TYPE.Number then
      evalStack:push(token)
    else
      local b = evalStack:pop()
      local a = evalStack:pop()
      local result = 0
      
      if token.type == TOKEN_TYPE.Add then result = a.value + b.value
      elseif token.type == TOKEN_TYPE.Subtract then result = a.value - b.value
      elseif token.type == TOKEN_TYPE.Multiply then result = a.value * b.value
      elseif token.type == TOKEN_TYPE.Divide then result = a.value / b.value
      end

      local resultToken = MakeToken(tostring(result), a.index)
      table.insert(steps, { a, b, token, resultToken })

      evalStack:push(resultToken)
    end
  end

  return evalStack.stack[1].value, steps
end

stepResults = {
  DeepCopy(infix)
}

function GetInfixStepByStep(infix, evaluatorSteps)
  stepResults = {
    DeepCopy(infix)
  }
  
  for _, step in pairs(evaluatorSteps) do
    local a = step[1]
    local b = step[2]
    local op = step[3]
    local result = step[4]

    infix[a.index] = -1
    infix[b.index] = -1
    infix[op.index] = -1
    infix[result.index] = result

    local processed = {}

    for _, v in pairs(infix) do
      if v ~= -1 then table.insert(processed, v) end
    end

    table.insert(stepResults, processed)
  end

  return stepResults
end

function GetStepByStepInfix(expression)
  local infix = Tokenize(expression)
  local postfix = InfixToPostfix(infix)
  local _, steps = Evaluate(postfix)
  local infixSteps = GetInfixStepByStep(infix, steps)

  return infixSteps
end

return {
  Tokenize = Tokenize,
  InfixToPostfix = InfixToPostfix,
  Evaluate = Evaluate,
  IsOperator = IsOperator,
  IsDigit = IsDigit,
  GetInfixStepByStep = GetInfixStepByStep
}