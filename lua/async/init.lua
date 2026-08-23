local M = {}

--- @alias Resolve<T> fun(...: T): nil
--- @alias Promise<T> fun(resolve: Resolve<T>): nil
--- @alias AsyncFn<T> fun(...: any): Promise<T>
--- @alias MakeAsync<T> fun(fn: fun(...: any): T): AsyncFn<T>
--- @alias SpawnFn fun(...: any): nil
--- @alias Spawn fun(fn: fun(...: any): any): SpawnFn

local function safe_resume(...)
  local ok, err = coroutine.resume(...)
  if not ok then error(err) end
end

--- @generic T
--- @param callback fun(resolve: Resolve<T>): nil
--- @return Promise<T>
M.from_executor = function(callback)
  return function(resolve)
    callback(resolve)
  end
end

--- @generic T
--- @param fn fun(...: any): T
--- @return AsyncFn<T>
M.make_async = function(fn)
  return function(...)
    local args = { ..., }
    return function(resolve)
      local thread = coroutine.create(function()
        local results = { fn(unpack(args)), }
        resolve(unpack(results))
      end)
      safe_resume(thread)
    end
  end
end

--- @type Spawn
M.spawn = function(fn)
  return function(...)
    local promise = M.make_async(fn)(...)
    promise(function() end)
  end
end

--- @generic T
--- @param promise Promise<T>
--- @return T
M.await = function(promise)
  local thread = coroutine.running()
  assert(thread ~= nil, "[async.nvim] `await` can only be called in a coroutine")
  local scheduled_promise = vim.schedule_wrap(promise)
  local resolve = vim.schedule_wrap(function(...) safe_resume(thread, ...) end)
  scheduled_promise(resolve)
  return coroutine.yield()
end

--- @class ThrottledIteratorOpts
--- @field threshold_ns? number
--- @field should_cancel? fun():boolean

--- @generic InvariantState, ControlVar
--- @param iterator_factory fun(): ((fun(invariant_state: InvariantState, control_var: ControlVar):ControlVar), InvariantState?, ControlVar?)
--- @param on_iteration fun(control_var: ControlVar, ...):nil
--- @param opts? ThrottledIteratorOpts
M.throttled_iterator = function(iterator_factory, on_iteration, opts)
  local promise = M.make_async(function()
    opts = opts or {}
    local threshold_ns = opts.threshold_ns or (10 * 1000000)
    local should_cancel = opts.should_cancel or (function() return false end)

    local function create_throttle()
      local last_yield = vim.uv.hrtime()
      return function()
        local now = vim.uv.hrtime()
        if (now - last_yield) >= threshold_ns then
          last_yield = now
          local thread = coroutine.running()
          vim.schedule(function() safe_resume(thread) end)
          coroutine.yield()
        end
      end
    end

    local maybe_pause = create_throttle()
    local iter_fn, invariant_state, control_var = iterator_factory()
    while true do
      if should_cancel() then
        return nil
      end
      maybe_pause()

      local values = { iter_fn(invariant_state, control_var), }
      control_var = values[1]

      if control_var == nil then
        return nil
      end

      on_iteration(unpack(values))
    end
  end)
  return promise()
end

return M
