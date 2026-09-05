local M = {}

--- @class BatchedIteratorOpts<InvariantState, ControlVar>
--- @field iterator_factory fun(): ((fun(invariant_state: InvariantState, control_var: ControlVar):ControlVar), InvariantState, ControlVar)
--- @field batch_size? number
--- @field should_cancel fun():boolean
--- @field on_iteration fun(entry: ControlVar):nil

--- @generic InvariantState, ControlVar
--- @param opts BatchedIteratorOpts<InvariantState, ControlVar>
--- @param callback fun(arg:nil):nil
local function batched_iterator_callback(opts, callback)
  opts = opts or {}
  local batch_size = opts.batch_size or 100
  local should_cancel = opts.should_cancel or function()
    return false
  end

  local iter_fn, invariant_state, control_var = opts.iterator_factory()
  local step
  step = function()
    local num_processed = 0
    while num_processed < batch_size do
      if should_cancel() then
        return
      end

      local values = { iter_fn(invariant_state, control_var) }
      control_var = values[1]

      if control_var == nil then
        callback(nil)
        return
      end

      on_iteration(unpack(values))
      num_processed = num_processed + 1
    end

    vim.schedule(step)
  end
  step()
end

--- @class ThrottledIteratorOpts<InvariantState, ControlVar>
--- @field iterator_factory fun(): ((fun(invariant_state: InvariantState, control_var: ControlVar):ControlVar), InvariantState?, ControlVar?)
--- @field threshold_ns? number
--- @field should_cancel? fun():boolean
--- @field on_iteration fun(control_var: ControlVar, ...):nil

--- @generic InvariantState, ControlVar
--- @param opts ThrottledIteratorOpts<InvariantState, ControlVar>
--- @param callback fun(arg:nil):nil
local throttled_iterator_callback = function(opts, callback)
  local threshold_ns = opts.threshold_ns or (10 * 1000000)
  local should_cancel = opts.should_cancel or function()
    return false
  end

  local function make_throttle()
    local last_yield = vim.uv.hrtime()
    return function()
      local now = vim.uv.hrtime()
      if (now - last_yield) >= threshold_ns then
        last_yield = now
        vim.async.sleep(0)
      end
    end
  end

  local maybe_pause = make_throttle()
  local iter_fn, invariant_state, control_var = opts.iterator_factory()
  while true do
    if should_cancel() then
      callback(nil)
      return
    end
    maybe_pause()

    local values = { iter_fn(invariant_state, control_var) }
    control_var = values[1]

    if control_var == nil then
      callback(nil)
      return
    end

    opts.on_iteration(unpack(values))
  end
end

M.throttled_iterator = vim.async.wrap(
  2,
  --- @generic InvariantState, ControlVar
  --- @param opts ThrottledIteratorOpts<InvariantState, ControlVar>
  --- @param callback fun(arg:nil):nil
  function(opts, callback)
    local task = vim.async.run("throttled_iterator_task", function()
      throttled_iterator_callback(opts, function()
        callback(nil)
      end)
    end)
    task:on_complete(function(err)
      if err then
        callback(err)
      end
    end)
    return task
  end
)

M.batched_iterator = vim.async.wrap(
  2,
  --- @generic InvariantState, ControlVar
  --- @param opts BatchedIteratorOpts<InvariantState, ControlVar>
  --- @param callback fun(arg:nil):nil
  function(opts, callback)
    local task = vim.async.run("batched_iterator_task", function()
      batched_iterator_callback(opts, function()
        callback(nil)
      end)
    end)
    task:on_complete(function(err)
      if err then
        callback(err)
      end
    end)
    return task
  end
)

return M
