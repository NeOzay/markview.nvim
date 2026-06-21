.PHONY: test test-file

test:
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run()"

test-file:
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"
