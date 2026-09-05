local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local M = require "async"

local wait_for = function(predicate)
  eq(vim.wait(100, predicate), true)
end

local run_callback = function(iterator_factory, opts)
  local result = {}
  vim.async.run("", function()
    M.throttled_iterator_callback(iterator_factory, opts, function(value)
      result.value = value
      result.done = true
    end)
  end)
  wait_for(function()
    return result.done == true
  end)
  return result.value
end

local T = new_set()

T["throttled_iterator_callback()"] = new_set()

T["throttled_iterator_callback()"]["iterates over all values"] = function()
  local seen = {}
  local result = {}
  vim.async.run(function()
    M.throttled_iterator_callback(function()
      return function(_, n)
        if n < 3 then
          return n + 1
        end
      end,
        nil,
        0
    end, {
      threshold_ns = 0,
      on_iteration = function(n)
        seen[#seen + 1] = n
      end,
    }, function(value)
      result.value = value
      result.done = true
    end)
  end)

  wait_for(function()
    return result.done == true
  end)
  eq(seen, { 1, 2, 3 })
  eq(result.value, nil)
end

T["throttled_iterator_callback()"]["passes iterator values to on_iteration"] = function()
  local calls = {}
  run_callback(function()
    return function(_, n)
      if n < 2 then
        return n + 1, "x" .. (n + 1)
      end
    end,
      nil,
      0
  end, {
    threshold_ns = 0,
    on_iteration = function(control_var, extra)
      calls[#calls + 1] = { control_var, extra }
    end,
  })
  eq(calls, { { 1, "x1" }, { 2, "x2" } })
end

T["throttled_iterator_callback()"]["cancels before the next iteration"] = function()
  local seen = {}
  local count = 0
  run_callback(function()
    return function(_, n)
      if n < 5 then
        return n + 1
      end
    end, nil, 0
  end, {
    threshold_ns = 0,
    on_iteration = function(n)
      seen[#seen + 1] = n
      count = count + 1
    end,
    should_cancel = function()
      return count >= 2
    end,
  })
  eq(seen, { 1, 2 })
end

T["throttled_iterator_callback()"]["yields before the first iteration when threshold is zero"] = function()
  local seen = {}
  local result = {}
  vim.async.run("", function()
    M.throttled_iterator_callback(function()
      return function(_, n)
        if n < 1 then
          return n + 1
        end
      end,
        nil,
        0
    end, {
      threshold_ns = 0,
      on_iteration = function(n)
        seen[#seen + 1] = n
      end,
    }, function()
      result.done = true
    end)
  end)

  eq(seen, {})
  eq(result.done, nil)
  wait_for(function()
    return result.done == true
  end)
  eq(seen, { 1 })
end

T["throttled_iterator_async()"] = new_set()

T["throttled_iterator_async()"]["runs the callback API in async context"] = function()
  local seen = {}
  local result = {}
  vim.async.run("", function()
    result.value = M.throttled_iterator_async {
      iterator_factory = function()
        return function(_, n)
          if n < 3 then
            return n + 1
          end
        end,
          nil,
          0
      end,
      opts = {
        threshold_ns = math.huge,
        on_iteration = function(n)
          seen[#seen + 1] = n
        end,
      },
    }
    result.done = true
  end)

  wait_for(function()
    return result.done == true
  end)
  eq(seen, { 1, 2, 3 })
  eq(result.value, nil)
end

return T
