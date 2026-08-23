local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local M = require "async"

local await_value = function(...)
  local result = {}
  local done = false
  local args = { ..., }

  coroutine.wrap(function()
    local promise = M.from_executor(function(resolve) resolve(unpack(args)) end)
    result = { M.await(promise), }
    done = true
  end)()

  vim.wait(10, function() return done end)
  return result
end

local capture_scheduled_errors = function(fn)
  local orig_schedule = vim.schedule
  local captured = nil
  vim.schedule = function(cb)
    orig_schedule(function()
      local ok, err = pcall(cb)
      if not ok then captured = err end
    end)
  end
  local ok, err = pcall(fn)
  vim.schedule = orig_schedule
  if not ok then error(err, 0) end
  return captured
end

local T = new_set()

T["await()"] = new_set()

T["await()"]["returns resolved value"] = function()
  eq(await_value(42), { 42, })
end

T["await()"]["returns multiple resolved values"] = function()
  eq(await_value(1, 2, 3), { 1, 2, 3, })
end

T["await()"]["errors when called outside coroutine"] = function()
  local promise = M.from_executor(function(resolve) resolve(42) end)
  local result = { pcall(M.await, promise), }
  eq(result[1], false)
  eq(result[2]:find "`await` can only be called in a coroutine" ~= nil, true)
end

T["await()"]["works inside async function"] = function()
  local promise = M.make_async(function()
    local inner_promise = M.from_executor(function(resolve) resolve(42) end)
    return M.await(inner_promise)
  end)

  local result = nil
  local done = false
  coroutine.wrap(function()
    result = { M.await(promise()), }
    done = true
  end)()
  vim.wait(1000, function() return done end)
  eq(result, { 42, })
end

T["await()"]["rejects when awaited promise throws"] = function()
  local bad = M.make_async(function() error "boom" end)
  local outer = M.make_async(function()
    return M.await(bad())
  end)

  local err = nil
  local done = false
  local promise = outer()
  promise(function() end, function(e)
    err = e
    done = true
  end)
  vim.wait(1000, function() return done end)
  eq({ done = done, boom = err and err:find "boom" ~= nil or false, }, { done = true, boom = true, })
end

T["await()"]["error is catchable inside async function"] = function()
  local bad = M.make_async(function() error "boom" end)
  local outer = M.make_async(function()
    local ok, err = pcall(M.await, bad())
    return { ok = ok, boom = err and err:find "boom" ~= nil or false, }
  end)

  local result = nil
  local done = false
  local promise = outer()
  promise(function(v)
    result = v
    done = true
  end, function() end)
  vim.wait(1000, function() return done end)
  eq(result, { ok = false, boom = true, })
end

T["await()"]["propagates non-string errors"] = function()
  local sentinel = { code = 42, }
  local bad = M.from_executor(function(_, reject)
    vim.schedule(function() reject(sentinel) end)
  end)
  local outer = M.make_async(function()
    return { pcall(M.await, bad), }
  end)

  local result = nil
  local done = false
  local promise = outer()
  promise(function(v)
    result = v
    done = true
  end, function() end)
  vim.wait(1000, function() return done end)
  eq({ done = done, ok = result[1], code = result[2] and result[2].code or nil, },
    { done = true, ok = false, code = 42, })
end

T["from_executor()"] = new_set()

T["from_executor()"]["resolves synchronously"] = function()
  local value = nil
  local done = false
  local promise = M.from_executor(function(resolve) resolve(42) end)
  promise(function(v)
    value = v
    done = true
  end)
  eq({ done = done, value = value, }, { done = true, value = 42, })
end

T["from_executor()"]["passes reject callback"] = function()
  local err = nil
  local done = false
  local promise = M.from_executor(function(_, reject) reject "nope" end)
  promise(function() end, function(e)
    err = e
    done = true
  end)
  eq({ done = done, msg = err, }, { done = true, msg = "nope", })
end

T["make_async()"] = new_set()

T["make_async()"]["resolves with return value"] = function()
  local value = nil
  local done = false
  local promise = M.make_async(function(a, b) return a + b end)(3, 4)
  promise(function(v)
    value = v
    done = true
  end)
  eq({ done = done, value = value, }, { done = true, value = 7, })
end

T["make_async()"]["resolves with multiple return values"] = function()
  local values = nil
  local done = false
  local promise = M.make_async(function() return 1, 2, 3 end)()
  promise(function(...)
    values = { ..., }
    done = true
  end)
  eq({ done = done, values = values, }, { done = true, values = { 1, 2, 3, }, })
end

T["make_async()"]["rejects when fn throws"] = function()
  local err = nil
  local done = false
  local promise = M.make_async(function() error "boom" end)()
  promise(function() end, function(e)
    err = e
    done = true
  end)
  eq({ done = done, boom = err and err:find "boom" ~= nil or false, }, { done = true, boom = true, })
end

T["make_async()"]["rethrows when no reject passed"] = function()
  local promise = M.make_async(function() error "boom" end)()
  local result = { pcall(promise, function() end), }
  eq(result[1], false)
  eq(result[2]:find "boom" ~= nil, true)
end

T["make_spawn()"] = new_set()

T["make_spawn()"]["executes async function immediately"] = function()
  local result = nil
  local spawn = M.make_spawn(function()
    result = 42
  end)
  spawn()
  eq(result, 42)
end

T["make_spawn()"]["passes arguments to async function"] = function()
  local result = nil
  local spawn = M.make_spawn(function(a, b)
    result = { a, b, }
  end)
  spawn(1, 2)
  eq(result, { 1, 2, })
end

T["make_spawn()"]["propagates errors"] = function()
  local result = { pcall(function()
    local spawn = M.make_spawn(function()
      error "boom"
    end)
    spawn()
  end), }
  eq(result[1], false)
  eq(result[2]:find "boom" ~= nil, true)
end

T["make_spawn()"]["does not hang on async error"] = function()
  local reached = false
  local captured = capture_scheduled_errors(function()
    local promise = M.from_executor(function(resolve)
      vim.schedule(function() resolve(1) end)
    end)
    M.make_spawn(function()
      M.await(promise)
      reached = true
      error "boom after await"
    end)()
    vim.wait(1000, function() return reached end)
  end)
  eq(reached, true)
  eq(captured and captured:find "boom after await" ~= nil or false, true)
end

T["throttled_iterator()"] = new_set()

T["throttled_iterator()"]["iterates over all values"] = function()
  local seen = {}
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 3 then return n + 1 end
      end, nil, 0
    end,
    function(n)
      seen[#seen + 1] = n
    end
  )

  local resolve = function() done = true end
  promise(resolve)
  vim.wait(10, function() return done end)
  eq(seen, { 1, 2, 3, })
end

T["throttled_iterator()"]["calls on_iteration with control variable"] = function()
  local calls = {}
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 2 then return n + 1, "x" .. (n + 1) end
      end, nil, 0
    end,
    function(control_var, extra)
      calls[#calls + 1] = { control_var, extra, }
    end
  )

  local resolve = function() done = true end
  promise(resolve)
  vim.wait(10, function() return done end)
  eq(calls, { { 1, "x1", }, { 2, "x2", }, })
end

T["throttled_iterator()"]["respects threshold_ns"] = function()
  local seen = {}
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 3 then return n + 1 end
      end, nil, 0
    end,
    function(n)
      seen[#seen + 1] = n
    end,
    { threshold_ns = 0, }
  )

  local resolve = function() done = true end
  promise(resolve)
  local immediate_count = #seen
  local immediate_done = done
  vim.wait(10, function() return done end)
  eq({
    immediate_count = immediate_count,
    immediate_done = immediate_done,
    final_count = #seen,
    final_done = done,
  }, { immediate_count = 0, immediate_done = false, final_count = 3, final_done = true, })
end

T["throttled_iterator()"]["cancels when should_cancel returns true"] = function()
  local seen = {}
  local done = false
  local count = 0

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 5 then return n + 1 end
      end, nil, 0
    end,
    function(n)
      seen[#seen + 1] = n
      count = count + 1
    end,
    { should_cancel = function() return count >= 2 end, }
  )

  local resolve = function() done = true end
  promise(resolve)
  vim.wait(10, function() return done end)
  eq({ seen = seen, done = done, }, { seen = { 1, 2, }, done = true, })
end

T["throttled_iterator()"]["resolves when iteration completes"] = function()
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 3 then return n + 1 end
      end, nil, 0
    end,
    function() end
  )

  local resolve = function() done = true end
  promise(resolve)
  vim.wait(10, function() return done end)
  eq(done, true)
end

T["throttled_iterator()"]["resolves when cancelled"] = function()
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 5 then return n + 1 end
      end, nil, 0
    end,
    function() end,
    { should_cancel = function() return true end, }
  )

  local resolve = function() done = true end
  promise(resolve)
  vim.wait(10, function() return done end)
  eq(done, true)
end

T["throttled_iterator()"]["rejects when on_iteration throws after yield"] = function()
  local err = nil
  local done = false

  local promise = M.throttled_iterator(
    function()
      return function(_, n)
        if n < 1 then return n + 1 end
      end, nil, 0
    end,
    function() error "iter boom" end,
    { threshold_ns = 0, }
  )

  promise(function() end, function(e)
    err = e
    done = true
  end)
  vim.wait(1000, function() return done end)
  eq({ done = done, boom = err and err:find "iter boom" ~= nil or false, }, { done = true, boom = true, })
end

T["integration"] = new_set()

T["integration"]["awaits async and callback promises inside make_spawn"] = function()
  local result = nil
  local done = false

  local add = M.make_async(function(a, b)
    return a + b
  end)

  local double = M.make_async(function(value)
    return value * 2
  end)

  local deferred = M.from_executor(function(resolve)
    vim.schedule(function() resolve(10) end)
  end)

  M.make_spawn(function()
    local sum = M.await(add(3, 4))
    local doubled = M.await(double(sum))
    local extra = M.await(deferred)
    result = { sum, doubled, extra, }
    done = true
  end)()

  vim.wait(1000, function() return done end)
  eq(result, { 7, 14, 10, })
end

return T
