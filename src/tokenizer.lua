local tokenizer = {}

-- Partition kinds definition
tokenizer.TEXT    = 0
tokenizer.COMMAND = 1

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
    return char:match("%w") ~= nil
end

-- helper function to check if character is the start of an identifier
function is_id_start(char)
    return char:match("%a") ~= nil
end

-- helper to check if word is a keyword
function is_keyword(word)
    return (word == "template" or
            word == "begin"    or
            word == "block")
end

-- transform plain text into the separation between normal text and commands for the templating
function tokenizer.partition(text)
    local parts = {}
    local acc = ""
    local skip = 0 -- how many characters to skip
    for i=1,#text do
        local char = idx(text, i)
        local next = idx(text, i)
        if i < #text then next = idx(text, i+1) end
        if char .. next == "%{" then
            table.insert(parts, { type = tokenizer.TEXT, value = acc })
            skip = 2
            acc = ""
        elseif char .. next == "}%" then
            table.insert(parts, { type = tokenizer.COMMAND, value = acc })
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
        table.insert(parts, { type = tokenizer.TEXT, value = acc })
    end
    return parts
end

-- tokenize command
function lex_command(text)
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
function tokenizer.lex(parts)
    local tokens = {}
    for i=1,#parts do
        local part = parts[i]
        if part.type == tokenizer.TEXT then
            table.insert(tokens, part.value)
        elseif part.type == tokenizer.COMMAND then
            -- tokenizing the command
            local toks = lex_command(part.value)
            table.insert(tokens, toks)
        end
    end
    return tokens
end

return tokenizer
