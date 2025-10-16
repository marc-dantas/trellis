#!/usr/bin/env lua

-- Partition kinds definition
TEXT    = 0
COMMAND = 1

-- helper to index a character from a string
function idx(text, index)
    return string.sub(text, index, index)
end

-- helper function to check if character is a whitespace
function isspace(char)
    return char:match("%s") ~= nil
end

-- helper function to check if character is part of an identifier
function is_id(char)
    return char:match("%w") ~= nil or char == "_"
end

-- helper function to check if character is the start of an identifier
function is_id_start(char)
    return char:match("%a") ~= nil or char == "_"
end

---- Lexical analysis

-- transform plain text into the separation between normal text and commands for the templating
function partition(text)
    local parts = {}
    local acc = ""
    local skip = 0 -- how many characters to skip
    for i=1,#text do
        local char = idx(text, i)
        local next = idx(text, i)
        if i < #text then next = idx(text, i+1) end
        if char .. next == "%{" then
            table.insert(parts, { type = TEXT, value = acc })
            skip = 2
            acc = ""
        elseif char .. next == "}%" then
            table.insert(parts, { type = COMMAND, value = acc })
            skip = 2
            acc = ""
        end
        if skip > 0 then
            skip = skip - 1
        else
            acc = acc .. char
        end
    end
    if #acc > 0 then
        table.insert(parts, { type = TEXT, value = acc })
    end
    return parts
end

-- tokenize command
function tokenize_command(text)
    local toks = {}
    local i = 1
    local acc = ""
    while i <= #text do
        local char = idx(text, i)
        if isspace(char) then
            if #acc > 0 then
                table.insert(toks, acc)
            end
            acc = ""
            i = i + 1
        elseif is_id_start(char) then
            local c = idx(text, i)
            while i <= #text do
                c = idx(text, i)
                if not is_id(c) then break end
                acc = acc .. c
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    if #acc > 0 then
        table.insert(toks, acc)
    end
    return toks
end

-- transform the partitioned text into a sequence of tokens
function tokenize(parts)
    local tokens = {}
    for i=1,#parts do
        local part = parts[i]
        if part.type == TEXT then
            table.insert(tokens, part.value)
        elseif part.type == COMMAND then
            -- tokenizing the command
            local toks = tokenize_command(part.value)
            table.insert(tokens, toks)
        end
    end
    return tokens
end

---- Parser



-- Syntax variants definition

local CommandKind = {
    END      = {},
    BLOCK    = {},
    TEMPLATE = {},
    BEGIN    = {}
}

function parse(tokens)
    for index, token in pairs(tokens) do
        if type(token) == "table" then
            -- in case of a command token
            local command = token[1]
            local sub = token[2]

            if command ~= nil then
                if command == "end" then
                    tokens[index] = { type = CommandKind.END }
                elseif command == "template" and sub ~= nil then
                    tokens[index] = { type = CommandKind.TEMPLATE, template = sub }
                elseif command == "block" and sub ~= nil then
                    tokens[index] = { type = CommandKind.BLOCK, block = sub }
                elseif command == "begin" and sub ~= nil then
                    tokens[index] = { type = CommandKind.BEGIN, block = sub }
                else
                    tokens[index] = nil
                end
            else
                tokens[index] = nil
            end
        end
    end
end

---- Main CLI program

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

    local parts = partition(content)
    local tokens = tokenize(parts)
    parse(tokens)
    
    for i=1,#tokens do
        local token = tokens[i]
        if type(token) == "table" then
            print("Command: {")
                if token.type == CommandKind.END then
                    print("    end")
                elseif token.type == CommandKind.TEMPLATE then
                    print("    template " .. token.template)
                elseif token.type == CommandKind.BLOCK then
                    print("    block " .. token.block)
                elseif token.type == CommandKind.BEGIN then
                    print("    begin " .. token.block)
                end
                
            print("}\n")
        end
    end

    return 0
end

os.exit(main())
