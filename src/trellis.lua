#!/usr/bin/env lua

local tokenizer = require("src/tokenizer")

function fatal(program, message)
    io.stderr:write(program .. ": fatal: " .. message .. "\n")
end

function usage(program)
    io.stderr:write("usage: " .. program .. " FILENAME\n")
end

function main()
    print("Trellis")
    local program = arg[0]
    local filename = arg[1]
    if filename == nil then
        usage(program)
        fatal(program, "expected at least 1 positional argument (filename)")
        return 1
    end

    local f = io.open(filename, "r")
    if f == nil then
        fatal(program, "could not open file `" .. filename .. "`.")
        return 1
    end

    local content = f:read("*all")
    if content == nil then
        fatal(program, "could not read file `" .. filename .. "`.")
        return 1
    end

    local parts = tokenizer.partition(content)
    local tokens = tokenizer.lex(parts)
    for i=1,#tokens do
        local token = tokens[i]
        if type(token) == "table" then
            print("Command: {")
            for _, i in pairs(token) do
                print("    \"" .. i .. "\"")
            end
            print("}\n")
        else
            print("Plain text: \"" .. token .. "\"\n")
        end
    end

    return 0
end

os.exit(main())
