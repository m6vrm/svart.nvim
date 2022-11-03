local function test(module)
    print("Begin test " .. module)
    package.loaded[module] = nil
    require(module).test()
    print("End test " .. module)
end

local function assert_eq(lhs, rhs, message)
    local lhs = vim.inspect(lhs)
    local rhs = vim.inspect(rhs)

    if lhs ~= rhs then
        local message = message or "assertion failed!"
        assert(false, message .. " ( " .. lhs .. " != " .. rhs .. " ) ")
    end
end

local function run()
    test("svart.utils")
--    test("svart.labels")
end

return {
    assert_eq = assert_eq,
    run = run,
}
