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

return T
