local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set {
  hooks = {
    pre_case = function()
      child.restart { "-u", "scripts/minimal_init.lua", }
    end,
    post_once = child.stop,
  },
}

T["dummy"] = function()
  eq(true, true)
end

T["await()"] = new_set()

T["await()"]["returns resolved value"] = function() end

T["await()"]["returns multiple resolved values"] = function() end

T["await()"]["errors when called outside coroutine"] = function() end

T["await()"]["works inside async function"] = function() end

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
