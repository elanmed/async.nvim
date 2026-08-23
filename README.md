# async.nvim

A tiny, dependency-free set of async primitives for Neovim plugins. Includes promises, async functions, spawn, and a throttled iterator.

## Promises as functions

In JavaScript, a promise is an object. In this plugin, I define a promise as a function that takes a `resolve` callback:

```lua
local promise = function(resolve)
  resolve(42)
end
```

`from_executor` helps formalize the idea:

```lua
local promise = from_executor(function(resolve)
  resolve(42)
end)
```

And it's useful for bridging callback-style APIs:

```lua
local promise = from_executor(function(resolve)
  vim.defer_fn(function()
    resolve("done")
  end, 100)
end)
```

## Async functions

In JavaScript, an `async` function has two capabilities that interest us:

1. It returns a promise
2. Within the `async` function, you can use the `await` keyword

We'll use the same terminology in this plugin.

## `make_async`

`make_async` takes a callback argument and transforms it, returning a new function. This new function is async - it returns a promise (matching #1 from above)

```lua
local add = make_async(function(a, b)
  return a + b
end)

local promise = add(3, 4) -- a promise
```

## `await`

`await` takes a promise and returns its resolved value. It must be called inside a coroutine — which is something else which `make_async` provides (matching #2 from above):

```lua
local add = make_async(function(a, b)
  return a + b
end)

local double = make_async(function(value)
  return value * 2
end)

local compute = make_async(function()
  local add_promise = add(3, 4)
  local sum = await(add_promise)
  local double_promise = double(sum)
  return await(double_promise)
end)
```

## spawn

To create a coroutine which `await` can be called in, but avoid returning a promise, you can use `spawn`:

```lua
local spawned = spawn(function()
  vim.print(await(compute())) -- 14
end)
spawned()
```

`spawn` runs an async function immediately and discards the result:

```lua
local spawned = spawn(function()
  vim.print("hello")
end)
spawned()
```

It's the fire-and-forget primitive: `make_async` returns an async function; calling it returns a promise for you to await. `spawn` starts the coroutine and moves on.

## throttled_iterator

For processing large lists without blocking the UI, `throttled_iterator` iterates in batches and yields back to the main thread between batches:

```lua
local promise = throttled_iterator(
  function()
    return function(_, n)
      if n < 3 then return n + 1 end
    end, nil, 0
  end,
  function(n)
    vim.print(n)
  end
)

promise(function(resolve)
  vim.print("done")
end)
```

Options:

- `threshold_ns`: how long to process before yielding (default: 10ms)
- `should_cancel`: a function returning `true` to stop early
