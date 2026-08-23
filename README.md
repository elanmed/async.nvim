# async.nvim

A tiny, dependency-free set of async primitives for Neovim plugins. Includes promises, async functions, spawn, and a throttled iterator.

## Promises are functions

In JavaScript, a promise is an object. In this plugin, I define a promise as a function that takes a `resolve` callback:

```lua
local promise = function(resolve)
  resolve(42)
end
```

`new_promise` helps formalize the idea:

```lua
local promise = new_promise(function(resolve)
  resolve(42)
end)
```

And it's useful for bridging callback-style APIs:

```lua
local delayed = new_promise(function(resolve)
  vim.defer_fn(function()
    resolve("done")
  end, 100)
end)
```

## `async`

`async` turns a plain function into an async function — one that returns (my definition of) a `promise` which automatically resolves with its return value:

```lua
local add = async(function(a, b)
  return a + b
end)

local promise = add(3, 4) -- a promise
```

In other words, the `promise` returned by `async` does not need to take in a `resolve` callback argument.

## `await`

`await` takes a promise and returns its resolved value. It must be called inside a coroutine — which is exactly what `async` provides:

```lua
local add = async(function(a, b)
  return a + b
end)

local double = async(function(value)
  return value * 2
end)

local compute = async(function()
  local sum = await(add(3, 4))
  return await(double(sum))
end)
```

`compute()` returns a promise. To run it and do something with the result, use `spawn`:

```lua
spawn(function()
  vim.print(await(compute())) -- 14
end)()
```

## spawn

`spawn` runs an async function immediately and discards the result:

```lua
spawn(function()
  vim.print("hello")
end)()
```

It' a the fire-and-forget primitive: `async` returns a promise for you to await, `spawn` starts the coroutine and moves on.

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

promise(function()
  vim.print("done")
end)
```

Options:

- `threshold_ns`: how long to process before yielding (default: 10ms)
- `should_cancel`: a function returning `true` to stop early
