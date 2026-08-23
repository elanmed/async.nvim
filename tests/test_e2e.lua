local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local await_value = function(...)
  return child.lua_func(function(...)
    local result = {}
    local done = false
    local args = { ..., }

    coroutine.wrap(function()
      result = { M.await(function(resolve) resolve(unpack(args)) end), }
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
    return { pcall(M.await, function(resolve) resolve(42) end), }
  end)
  eq(result[1], false)
  eq(result[2]:find "`await` can only be called in a coroutine" ~= nil, true)
end

T["await()"]["works inside async function"] = function()
  eq(child.lua_func(function()
    local result, done = {}, false
    M.unwaited_async(function()
      result = { M.await(function(resolve) resolve(42) end), }
      done = true
    end)()
    vim.wait(10, function() return done end)
    return result
  end), { 42, })
end

T["unwaited_async()"] = new_set()

T["unwaited_async()"]["executes async function immediately"] = function() end

T["unwaited_async()"]["passes arguments to async function"] = function() end

T["unwaited_async()"]["propagates errors"] = function() end

T["throttled_iterator()"] = new_set()

T["throttled_iterator()"]["iterates over all values"] = function() end

T["throttled_iterator()"]["calls on_iteration with control variable"] = function() end

T["throttled_iterator()"]["respects threshold_ns"] = function() end

T["throttled_iterator()"]["cancels when should_cancel returns true"] = function() end

T["throttled_iterator()"]["resolves when iteration completes"] = function() end

T["throttled_iterator()"]["resolves when cancelled"] = function() end

return T
