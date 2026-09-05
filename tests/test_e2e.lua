local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local M = require "async"

local wait_for = function(predicate)
  eq(vim.wait(100, predicate), true)
end

local run_async = function(opts)
  local result = {}
  vim.async.run("run_async_task", function()
    result.value = M.throttled_iterator(opts)
    result.done = true
  end)
  wait_for(function()
    return result.done == true
  end)
  return result.value
end

local T = new_set()

T["throttled_iterator()"] = new_set()

T["throttled_iterator()"]["runs the callback API in async context"] = function()
  local seen = {}
  local result = {}
  vim.async.run("runs_callback_task", function()
    result.value = M.throttled_iterator {
      iterator_factory = function()
        return function(_, n)
          if n < 3 then
            return n + 1
          end
        end,
          nil,
          0
      end,
      threshold_ns = math.huge,
      on_iteration = function(n)
        seen[#seen + 1] = n
      end,
    }
    result.done = true
  end)

  wait_for(function()
    return result.done == true
  end)
  eq(seen, { 1, 2, 3 })
  eq(result.value, nil)
end

T["throttled_iterator()"]["returns iterator factory errors"] = function()
  local err = run_async {
    iterator_factory = function()
      error "iterator factory error"
    end,
    on_iteration = function() end,
  }
  eq(err:match "iterator factory error", "iterator factory error")
end

T["throttled_iterator()"]["returns on_iteration errors"] = function()
  local err = run_async {
    iterator_factory = function()
      return function(_, n)
        return n + 1
      end, nil, 0
    end,
    threshold_ns = math.huge,
    on_iteration = function()
      error "on_iteration error"
    end,
  }
  eq(err:match "on_iteration error", "on_iteration error")
end

return T
