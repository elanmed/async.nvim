local M = {}

local function safe_resume(...)
  local ok, err = coroutine.resume(...)
  if not ok then error(err) end
end

--- @generic T
--- @param fn fun(resolve: Resolve<T>, ...: any): nil
--- @return fun(...: any): Promise<T>
local async = function(fn)
  return function(...)
    local args = { ..., }
    return function(resolve)
      local thread = coroutine.create(fn)
      safe_resume(thread, resolve, unpack(args))
    end
  end
end

--- @alias Resolve<T> fun(value?: T): nil
--- @alias Promise<T> fun(resolve: Resolve<T>): nil

--- @param fn fun(resolve: Resolve<any>, ...: any): nil
M.unwaited_async = function(fn)
  return function(...)
    local promise = async(fn)(...)
    promise(function() end)
  end
end

--- @generic T
--- @param promise Promise<T>
--- @return T
M.await = function(promise)
  local thread = coroutine.running()
  assert(thread ~= nil, "`await` can only be called in a coroutine")
  local scheduled_promise = vim.schedule_wrap(promise)
  local resolve = vim.schedule_wrap(function(...) safe_resume(thread, ...) end)
  scheduled_promise(resolve)
  return coroutine.yield()
end

-- ====================
-- Misc utils
-- ====================

--- @param level vim.log.levels
--- @param msg string
--- @param ... any
local notify = function(level, msg, ...)
  msg = "[tree.nvim]: " .. msg
  vim.notify(msg:format(...), level)
end

return M
