local function test(module)
    package.loaded[module] = nil
    require(module).test()
    print(module .. " test passed")
end

local function assert_eq(lhs, rhs, message)
    local lhs = vim.inspect(lhs)
    local rhs = vim.inspect(rhs)

    if lhs ~= rhs then
        local message = message or "assertion failed!"
        assert(false, message .. " ( " .. lhs .. " != " .. rhs .. " )")
    end
end

local function run()
    test("svart.utils")
    test("svart.labels")
    test("svart.search")
end

return {
    assert_eq = assert_eq,
    run = run,
}
