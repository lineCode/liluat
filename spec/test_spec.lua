local liluat = require("liluat")

describe("liluat", function ()
	it("should return an empty string for empty templates", function ()
		assert.equal("", liluat.render(liluat.loadstring(""), {}))
	end)

	it("should render some example template", function ()
		local tmpl = liluat.loadstring([[<span>
#{ if user ~= nil then }#
Hello, #{= escapeHTML(user.name) }#!
#{ else }#
<a href="/login">login</a>
#{ end }#
</span>
]])

		local expected_output = [[<span>

Hello, &lt;world&gt;!

</span>
]]

		local function escapeHTML(str)
			local tt = {
				['&'] = '&amp;',
				['<'] = '&lt;',
				['>'] = '&gt;',
				['"'] = '&quot;',
				["'"] = '&#39;',
			}
			local r = str:gsub('[&<>"\']', tt)
			return r
		end

		assert.equal(expected_output, liluat.render(tmpl, {user = {name = "<world>"}, escapeHTML = escapeHTML }))
	end)

	describe("clone_table", function ()
		it("should clone a table", function ()
			local table = {
				a = {
					b = 1,
					c = {
						d = 2
					}
				},
				e = 3
			}

			local clone = liluat.private.clone_table(table)

			assert.same(table, clone)
			assert.not_equal(table, clone)
			assert.not_equal(table.a, clone.a)
			assert.not_equal(table.a.c, clone.a.c)
		end)
	end)

	describe("merge_tables", function ()
		it("should merge two tables", function ()
			local a = {
				a = 1,
				b = 2,
				c = {
					d = 3,
					e = {
						f = 4
					}
				},
				g = {
					h = 5
				}
			}

			local b = {
				b = 3,
				x = 5,
				y = {
					z = 4
				},
				c = {
					j = 5
				}
			}

			local expected_output = {
				a = 1,
				b = 3,
				c = {
					d = 3,
					e = {
						f = 4
					},
					j = 5
				},
				g = {
					h = 5
				},
				x = 5,
				y = {
					z = 4
				}
			}

			assert.same(expected_output, liluat.private.merge_tables(a, b))
		end)

		it("should merge nil tables", function ()
			local a = {
				a = 1
			}

			assert.same({a = 1}, liluat.private.merge_tables(nil, a))
			assert.same({a = 1}, liluat.private.merge_tables(a, nil))
			assert.same({}, liluat.private.merge_tables(nil, nil))
		end)
	end)

	describe("escape_pattern", function ()
		it("should escape lua pattern special characters", function ()
			local input = ".%a%c%d%l%p%s%u%w%x%z().%%+-*?[]^$"
			local expected_output = "%.%%a%%c%%d%%l%%p%%s%%u%%w%%x%%z%(%)%.%%%%%+%-%*%?%[%]%^%$"
			local escaped_pattern = liluat.private.escape_pattern(input)

			assert.equals(expected_output, escaped_pattern)
			assert.truthy(input:find(escaped_pattern))
		end)
	end)

	describe("all_chunks", function ()
		it("should iterate over all chunks", function ()
			local template = [[
#{= expression}# bla #{code}#
 #{other code}# some text
#{more code}##{}#
#{include: "bla"}#
some more text]]
			local result = {}

			for chunk in liluat.private.all_chunks(template) do
				table.insert(result, chunk)
			end

			local expected_output = {
				{
					text = "#{= expression}#",
					type = "expression"
				},
				{
					text = " bla ",
					type = "text"
				},
				{
					text = "#{code}#",
					type = "code"
				},
				{
					text = "\n ",
					type = "text"
				},
				{
					text = "#{other code}#",
					type = "code"
				},
				{
					text = " some text\n",
					type = "text"
				},
				{
					text = "#{more code}#",
					type = "code"
				},
				{
					text = "#{}#",
					type = "code"
				},
				{
					text = "\n",
					type = "text"
				},
				{
					text = '#{include: "bla"}#',
					type = "include"
				},
				{
					text = "\nsome more text",
					type = "text"
				}
			}

			assert.same(expected_output, result)
		end)
	end)

	describe("read_entire_file", function ()
		local file_content = liluat.private.read_entire_file("spec/read_entire_file-test")
		local expected = "This should be read by the 'read_entire_file' helper functions.\n"

		assert.equal(expected, file_content)
	end)

	describe("parse_string_literal", function()
		it("should properly resolve escape sequences", function ()
			local expected = "bl\"\'\\ub" .. "\n\t\r" .. "bla"
			local input = "\"bl\\\"\\\'\\\\ub\" .. \"\\n\\t\\r\" .. \"bla\""

			assert.equal(expected, liluat.private.parse_string_literal(input))
		end)
	end)

	describe("liluat.lex", function ()
		it("should create a list of chunks", function ()
			local template = [[
#{= expression}# bla #{code}#
 #{other code}# some text
#{more code}##{}#
some more text]]

			local expected_output = {
				{
					text = "#{= expression}#",
					type = "expression"
				},
				{
					text = " bla ",
					type = "text"
				},
				{
					text = "#{code}#",
					type = "code"
				},
				{
					text = "\n ",
					type = "text"
				},
				{
					text = "#{other code}#",
					type = "code"
				},
				{
					text = " some text\n",
					type = "text"
				},
				{
					text = "#{more code}#",
					type = "code"
				},
				{
					text = "#{}#",
					type = "code"
				},
				{
					text = "\nsome more text",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.lex(template))
		end)

		it("should include files", function ()
			local template = [[
first line
#{include: "spec/read_entire_file-test"}#
another line]]

			local expected_output = {
				{
					text = "first line\nThis should be read by the 'read_entire_file' helper functions.\n\nanother line",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.lex(template))
		end)

		it("should work with other start and end tags", function ()
			local template = "text {%--template%} more text"
			local expected_output = {
				{
					text = "text ",
					type = "text"
				},
				{
					text = "{%--template%}",
					type = "code"
				},
				{
					text = " more text",
					type = "text"
				}
			}

			local options = {
				start_tag = "{%",
				end_tag = "%}"
			}
			assert.same(expected_output, liluat.lex(template, options))
		end)

		it("should use existing table if specified", function ()
			local template = "bla {{= 5}} more bla"
			local output = {}
			local expected_output = {
				{
					text = "bla ",
					type = "text"
				},
				{
					text = "{{= 5}}",
					type = "expression"
				},
				{
					text = " more bla",
					type = "text"
				}
			}

			local options = {
				start_tag = "{{",
				end_tag = "}}"
			}
			local result = liluat.lex(template, options, output)

			assert.equal(output, result)
			assert.same(expected_output, result)
		end)

		it("should detect cyclic inclusions", function ()
			local template = liluat.private.read_entire_file("spec/cycle_a.template")

			assert.has_error(
				function ()
					liluat.lex(template)
				end,
				"Cyclic inclusion detected")
		end)

		it("should not create two or more text chunks in a row", function ()
			local template = 'text#{include: "spec/content.html.template"}#more text'

			local expected_output = {
				{
					text = "text<h1>This is the index page.</h1>\nmore text",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.lex(template))
		end)
	end)

	describe("sandbox", function ()
		it("should run code in a sandbox", function ()
			local code = "return i, 1"
			local i = 1
			local a, b = liluat.private.sandbox(code)()

			assert.is_nil(a)
			assert.equal(1, b)
		end)

		it("should pass an environment", function ()
			local code = "return i"
			assert.equal(1, liluat.private.sandbox(code, nil, {i = 1})())
		end)

		it("should not have access to non-whitelisted functions", function ()
			local code = "return load"
			assert.is_nil(liluat.private.sandbox(code)())
		end)

		it("should have access to whitelisted functions", function ()
			local code = "return os.time"
			assert.is_function(liluat.private.sandbox(code)())
		end)

		it("should accept custom whitelists", function ()
			local code = "return string and string.find"
			assert.is_nil(liluat.private.sandbox(code, nil, nil, {})())
		end)
	end)

	describe("liluat.loadstring", function ()
		it("should compile templates into code", function ()
			local template = "a#{i = 0}##{= i}#b"
			local expected_output = {
				name = "=(liluat.loadstring)",
				code = [[
coroutine.yield("a")
i = 0
coroutine.yield( i)
coroutine.yield("b")]]
			}

			assert.same(expected_output, liluat.loadstring(template))
		end)

		it("should accept template names", function ()
			local template = "a"
			local template_name = "my template"
			local expected_output = {
				name = "my template",
				code = 'coroutine.yield("a")'
			}

			assert.same(expected_output, liluat.loadstring(template, template_name))
		end)

		it("should accept other template tags passed as options", function ()
			local template = "a{{i = 0}}{{= i}}b"
			local options = {
				start_tag = "{{",
				end_tag = "}}"
			}
			local expected_output = {
				name = "=(liluat.loadstring)",
				code = [[
coroutine.yield("a")
i = 0
coroutine.yield( i)
coroutine.yield("b")]]
			}

			assert.same(expected_output, liluat.loadstring(template, nil, options))
		end)
	end)

	describe("liluat.loadfile", function ()
		it("should load a template file", function ()
			local template_path = "spec/index.html.template"
			local expected_output = loadfile("spec/index.html.template.lua")()

			assert.same(expected_output, liluat.loadfile(template_path))
		end)

		it("should accept different tags via the options", function ()
			local template_path = "spec/jinja.template"
			local options = {
				start_tag = "{%",
				end_tag = "%}"
			}
			local expected_output = loadfile("spec/jinja.template.lua")()

			assert.same(expected_output, liluat.loadfile(template_path, options))
		end)
	end)

	describe("get_dependency", function ()
		it("should list all includes", function ()
			local template = '#{include: "spec/index.html.template"}#'
			local expected_output = {
				"spec/index.html.template",
				"spec/content.html.template"
			}

			assert.same(expected_output, liluat.get_dependency(template))
		end)

		it("should list every file only once", function ()
			local template = '#{include: "spec/index.html.template"}##{include: "spec/index.html.template"}#'
			local expected_output = {
				"spec/index.html.template",
				"spec/content.html.template"
			}

			assert.same(expected_output, liluat.get_dependency(template))
		end)
	end)

	describe("liluat.precompile", function ()
		it("should precompile a template", function ()
			local template = liluat.private.read_entire_file("spec/index.html.template")
			local expected_output = liluat.private.read_entire_file("spec/index.html.template.precompiled")

			assert.equal(expected_output, liluat.precompile(template))
		end)
	end)

	describe("sandbox", function ()
		it("should run code in a sandbox", function ()
			local code = "return i, 1"
			local i = 1
			local a, b = liluat.private.sandbox(code)()

			assert.is_nil(a)
			assert.equal(1, b)
		end)

		it("should pass an environment", function ()
			local code = "return i"
			assert.equal(1, liluat.private.sandbox(code, nil, {i = 1})())
		end)

		it("should not have access to non-whitelisted functions", function ()
			local code = "return load"
			assert.is_nil(liluat.private.sandbox(code)())
		end)

		it("should have access to whitelisted functions", function ()
			local code = "return os.time"
			assert.is_function(liluat.private.sandbox(code)())
		end)
	end)

	describe("add_include_and_detect_cycles", function ()
		it("should add includes", function ()
			local include_list = {}

			liluat.private.add_include_and_detect_cycles(include_list, "a")
			liluat.private.add_include_and_detect_cycles(include_list.a, "b")
			liluat.private.add_include_and_detect_cycles(include_list.a.b, "c")
			liluat.private.add_include_and_detect_cycles(include_list, "d")

			assert.is_nil(include_list[0])
			assert.equal(include_list, include_list.a[0])
			assert.is_table(include_list.a)
			assert.equal(include_list.a, include_list.a.b[0])
			assert.is_table(include_list.a.b)
			assert.equal(include_list.a.b, include_list.a.b.c[0])
			assert.is_table(include_list.a.b.c)
			assert.is_equal(include_list, include_list.d[0])
			assert.is_table(include_list.d)
		end)

		it("should detect inclusion cycles", function ()
			local include_list = {}

			liluat.private.add_include_and_detect_cycles(include_list, "a")
			liluat.private.add_include_and_detect_cycles(include_list.a, "b")
			assert.has_error(
				function ()
					liluat.private.add_include_and_detect_cycles(include_list.a.b, "a")
				end,
				"Cyclic inclusion detected")
		end)
	end)

	describe("dirname", function ()
		it("should return the directory containing a file", function ()
			assert.equal("/home/user/", liluat.private.dirname("/home/user/.bashrc"))
			assert.equal("/home/user/", liluat.private.dirname("/home/user/"))
			assert.equal("/home/", liluat.private.dirname("/home/user"))
			assert.equal("./", liluat.private.dirname("./template"))
			assert.equal("", liluat.private.dirname("."))
		end)
	end)
end)
