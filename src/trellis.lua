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

---- Rendering engine

-- rust vibes coming
local Result = {
    OK = {},
    ERR = {}
}

function render(data)
    local template = {}
    for index, item in pairs(data) do
        if type(item) == "table" and item.type == CommandKind.TEMPLATE then
            template = read_trellis(item.template .. ".html")
            if template == nil then return nil end 
        end
    end

    local blocks = {}
    local block = nil
    
    for index, item in pairs(data) do
        if type(item) == "table" then
            if item.type == CommandKind.BEGIN then
                block = item.block
                blocks[item.block] = ""
            elseif item.type == CommandKind.END then
                block = nil
            end
        elseif type(item) == "string" then
            if block ~= nil then
                blocks[block] = blocks[block] .. item
            end
        end
    end

    local rendered = ""
    for index, item in pairs(template) do
        if type(item) == "string" then
            rendered = rendered .. item
        elseif type(item) == "table" then
            if item.type == CommandKind.BLOCK then
                if blocks[item.block] ~= nil then
                    rendered = rendered .. blocks[item.block]
                end
            end
        end
    end
    return rendered
end

---- Main CLI program

function fatal(program, message)
    io.stderr:write(program .. ": fatal: " .. message .. "\n")
end

function usage(program)
    io.stderr:write("usage: " .. program .. " FILENAME OUTPUT\n")
end

function read_entire_file(filename)
    local f = io.open(filename, "r")
    if f == nil then return nil end
    local content = f:read("*all")
    if content == nil then return nil end
    io.close(f)
    return content
end

function read_trellis(filename)
    local content = read_entire_file(filename)
    if content == nil then return nil end
    local trellis = tokenize(partition(content))
    parse(trellis)
    return trellis
end

function main()
    print("Trellis")
    local program = arg[0]
    local filename = arg[1]
    local output = arg[2]
    if filename == nil then
        usage(program)
        fatal(program, "expected at least 2 positional argument (filename and output)")
        return 1
    end
    if output == nil then
        usage(program)
        fatal(program, "expected at least 2 positional argument (filename and output)")
        return 1
    end

    local content = read_entire_file(filename)

    local trellis = read_trellis(filename)
    if trellis == nil then
        fatal(program, "could not read file `" .. filename .. "`.")
        return 1
    end

    local rendered = render(trellis)
    if rendered == nil then
        fatal(program, "could not render `" .. filename .. "`.")
    end

    local out = io.open(output, "w")
    out:write(rendered)
    return 0
end

os.exit(main())
