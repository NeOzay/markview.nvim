-- Bootstrap mini.test: check lazy installs first, then fall back to deps/
local lazy_data = vim.fn.stdpath("data") .. "/lazy"
local mini_test_path =
  (vim.uv.fs_stat(lazy_data .. "/mini.test") and lazy_data .. "/mini.test")
  or (vim.uv.fs_stat(lazy_data .. "/mini.nvim") and lazy_data .. "/mini.nvim")

if not mini_test_path then
  mini_test_path = vim.fn.getcwd() .. "/deps/mini.test"
  if not vim.uv.fs_stat(mini_test_path) then
    vim.fn.system({
      "git", "clone", "--filter=blob:none",
      "https://github.com/echasnovski/mini.test",
      mini_test_path,
    })
  end
end

vim.opt.rtp:prepend(mini_test_path)
-- markview.nvim itself
vim.opt.rtp:prepend(vim.fn.getcwd())
-- treesitter parsers (markdown.so, markdown_inline.so…)
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")

require("mini.test").setup()
