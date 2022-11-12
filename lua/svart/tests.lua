local M = {}

local function test(module)
    package.loaded[module] = nil
    require(module).test(M)
    print(module .. " test passed")
end

function M.assert_eq(lhs, rhs, message)
    local lhs = vim.inspect(lhs)
    local rhs = vim.inspect(rhs)

    if lhs ~= rhs then
        local message = message or "assertion failed!"
        assert(false, message .. " ( " .. lhs .. " != " .. rhs .. " )")
    end
end

function M.run()
    test("svart.utils")
    test("svart.labels")
    test("svart.search")
    test("svart.win")
end

return M
