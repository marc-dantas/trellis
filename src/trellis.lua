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

---- Error handling

function warn(message, filename, line)
    io.stderr:write("warning: " .. filename .. ":" .. line .. ": " .. message .."\n")
end

function err(message, filename, line)
    io.stderr:write("error: " .. filename .. ":" .. line .. ": " .. message .."\n")
end

---- Lexical analysis

-- transform plain text into the separation between normal text and commands for the templating
function partition(text)
    local parts = {}
    local acc = ""
    local skip = 0 -- how many characters to skip
    local line = 1
    for i=1,#text do
        local char = idx(text, i)
        local next = idx(text, i)
        if i < #text then next = idx(text, i+1) end

        if char == "\n" then
            line = line + 1
        end
        
        if char .. next == "%{" then
            table.insert(parts, { type = TEXT, value = acc, line = line })
            skip = 2
            acc = ""
        elseif char .. next == "}%" then
            table.insert(parts, { type = COMMAND, value = acc, line = line })
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
            table.insert(tokens, { value = part.value, line = part.line })
        elseif part.type == COMMAND then
            -- tokenizing the command
            local toks = tokenize_command(part.value)
            table.insert(tokens, { value = toks, line = part.line })
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

function parse(filename, tokens)
    local data = {}
    for index, token in pairs(tokens) do
        local item = nil
        if type(token.value) == "table" then
            -- in case of a command token
            local command = token.value[1]
            local sub = token.value[2]

            if command ~= nil then
                if command == "end" then
                    thing = { type = CommandKind.END }
                elseif command == "template" and sub ~= nil then
                    thing = { type = CommandKind.TEMPLATE, template = sub }
                elseif command == "block" and sub ~= nil then
                    thing = { type = CommandKind.BLOCK, block = sub }
                elseif command == "begin" and sub ~= nil then
                    thing = { type = CommandKind.BEGIN, block = sub }
                else
                    err("invalid command or command format `" .. command .. "`", filename, token.line)
                    return nil
                end
            else
                err("no command specified", filename, token.line)
                return nil
            end
        else
            thing = token.value
        end
        
        table.insert(data, { value = thing, line = token.line })
    end
    return data
end

---- Rendering engine

function render(filename, data, is_template)
    local template = {}
    local template_filename = nil
    for index, item in pairs(data) do
        if type(item.value) == "table" and item.value.type == CommandKind.TEMPLATE then
            if template_filename ~= nil then
                err("multiple templates in an extension file are forbidden", filename, item.line)
                log("extension files must extend only from exactly one template")
                log("please remove this directive")
                return nil
            end
            
            local template_name = item.value.template .. ".html"
            template = load_trellis_file(template_name)
            if template == nil then
                err("could not read template `" .. template_name .. "`", filename, item.line)
                return nil
            end
            
            template = render(template_name, template, true)
            if template == nil then
                err("could not render template `" .. template_name .. "`", filename, item.line)
                return nil
            end

            template = parse(template_name, tokenize(partition(template)))
            if template == nil then
                err("could not render template `" .. template_name .. "`", filename, item.line)
                return nil
            end
            
            template_filename = template_name
        end
    end
    if template_filename == nil and not is_template then
        fatal("extension `" .. filename .. "` has no template to extend from")
        log("use `%{template <NAME>}%` command to specify one", "help")
        return nil
    end

    local blocks = {}
    local block = nil
    local rendered = ""
    
    for index, item in pairs(data) do
        if type(item.value) == "table" then
            if item.value.type == CommandKind.BEGIN then
                block = item.value.block
                blocks[item.value.block] = ""
            elseif item.value.type == CommandKind.END then
                block = nil
            elseif item.value.type == CommandKind.BLOCK then
                local dir = "%{block " .. item.value.block .. "}%"
                if block ~= nil then
                    blocks[block] = blocks[block] .. dir
                else
                    rendered = rendered .. dir
                end
            end
        elseif type(item.value) == "string" then
            if block ~= nil then
                blocks[block] = blocks[block] .. item.value
            else
                rendered = rendered .. item.value
            end
        end
    end

    for index, item in pairs(template) do
        if type(item.value) == "string" then
            rendered = rendered .. item.value
        elseif type(item.value) == "table" then
            if item.value.type == CommandKind.BLOCK then
                if blocks[item.value.block] == nil then
                    warn("block `" .. item.value.block .. "` is not used in extension `" .. filename .. "`", template_filename, item.line)
                else
                    rendered = rendered .. blocks[item.value.block]
                end
            end
        end
    end
    return rendered
end

---- Main CLI program

function log(message, submessage)
    io.stderr:write("info: ")
    if submessage ~= nil then
        io.stderr:write(submessage .. ": ")
    end
    io.stderr:write(message .. "\n")
end

function fatal(message)
    io.stderr:write("fatal: " .. message .. "\n")
end

function usage(program)
    io.stderr:write("usage: " .. program .. " FILENAME OUTPUT\n")
end

function read_entire_file(filename)
    local f = io.open(filename, "r")
    if f == nil then
        fatal("failed to open `" .. filename .. "`")
        return nil
    end
    local content = f:read("*all")
    if content == nil then
        fatal("failed to read `" .. filename .. "`")
        return nil
    end
    io.close(f)
    return content
end

function load_trellis_file(filename)
    local content = read_entire_file(filename)
    if content == nil then return nil end
    local trellis = parse(filename, tokenize(partition(content)))
    if trellis == nil then return nil end
    return trellis
end

function main()
    print("Trellis")
    print("A simple and powerful templating engine\n")
    local program = arg[0]
    local filename = arg[1]
    local output = arg[2]
    if filename == nil then
        usage(program)
        fatal("expected at least 2 positional arguments (filename and output)")
        return 1
    end
    if output == nil then
        usage(program)
        fatal("expected at least 2 positional arguments (filename and output)")
        return 1
    end

    local trellis = load_trellis_file(filename)
    if trellis == nil then return 1 end

    log("rendering `" .. filename .. "`")

    local rendered = render(filename, trellis)
    if rendered == nil then return 1 end

    local out = io.open(output, "w")
    out:write(rendered)
    log("rendered `" .. filename .. "` successfully into `" .. output .. "`")
    return 0
end

os.exit(main())
