local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local await_value = function(...)
  return child.lua_func(function(...)
    local result = {}
    local done = false
    local args = { ..., }

    coroutine.wrap(function()
      local promise = M.new_promise(function(resolve) resolve(unpack(args)) end)
      result = { M.await(promise), }
      done = true
    end)()

    vim.wait(10, function() return done end)
    return result
  end, ...)
end

local T = new_set {
  hooks = {
    pre_case = function()
      child.restart { "-u", "scripts/minimal_init.lua", }
      child.lua_func(function() M = require "async" end)
    end,
    post_once = child.stop,
  },
}

T["dummy"] = function()
  eq(true, true)
end

T["await()"] = new_set()

T["await()"]["returns resolved value"] = function()
  eq(await_value(42), { 42, })
end

T["await()"]["returns multiple resolved values"] = function()
  eq(await_value(1, 2, 3), { 1, 2, 3, })
end

T["await()"]["errors when called outside coroutine"] = function()
  local result = child.lua_func(function()
    local promise = M.new_promise(function(resolve) resolve(42) end)
    return { pcall(M.await, promise), }
  end)
  eq(result[1], false)
  eq(result[2]:find "`await` can only be called in a coroutine" ~= nil, true)
end

T["await()"]["works inside async function"] = function()
  eq(child.lua_func(function()
    local promise = M.async(function()
      local inner_promise = M.new_promise(function(resolve) resolve(42) end)
      return M.await(inner_promise)
    end)

    local result, done = nil, false
    coroutine.wrap(function()
      result = { M.await(promise()), }
      done = true
    end)()
    vim.wait(1000, function() return done end)
    return result
  end), { 42, })
end

T["spawn()"] = new_set()

T["spawn()"]["executes async function immediately"] = function()
  eq(child.lua_func(function()
    local result = nil
    local spawned = M.spawn(function()
      result = 42
    end)
    spawned()
    return result
  end), 42)
end

T["spawn()"]["passes arguments to async function"] = function()
  eq(child.lua_func(function()
    local result = nil
    local spawned = M.spawn(function(a, b)
      result = { a, b, }
    end)
    spawned(1, 2)
    return result
  end), { 1, 2, })
end

T["spawn()"]["propagates errors"] = function()
  local result = child.lua_func(function()
    return { pcall(function()
      local spawned = M.spawn(function()
        error "boom"
      end)
      spawned()
    end), }
  end)
  eq(result[1], false)
  eq(result[2]:find "boom" ~= nil, true)
end

T["throttled_iterator()"] = new_set()

T["throttled_iterator()"]["iterates over all values"] = function() end

T["throttled_iterator()"]["calls on_iteration with control variable"] = function() end

T["throttled_iterator()"]["respects threshold_ns"] = function() end

T["throttled_iterator()"]["cancels when should_cancel returns true"] = function() end

T["throttled_iterator()"]["resolves when iteration completes"] = function() end

T["throttled_iterator()"]["resolves when cancelled"] = function() end

T["overall"] = new_set()

T["overall"]["awaits twice inside spawned async function"] = function()
  eq(child.lua_func(function()
    local result, done = nil, false

    local add = M.async(function(a, b)
      return a + b
    end)

    local double = M.async(function(value)
      return value * 2
    end)

    M.spawn(function()
      local sum = M.await(add(3, 4))
      local doubled = M.await(double(sum))
      result = { sum, doubled, }
      done = true
    end)()

    vim.wait(1000, function() return done end)
    return result
  end), { 7, 14, })
end

return T
