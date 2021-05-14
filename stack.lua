Stack = {}

function Stack.new()
  o = {}
  o.stack = {}
  setmetatable(o, { __index = Stack })
  return o
end

function Stack:push(value)
  table.insert(self.stack, value)
end

function Stack:top()
  value = self.stack[#self.stack]
  return value
end

function Stack:pop()
  local top = self:top()
  table.remove(self.stack, #self.stack)
  return top
end

return Stack