---@class bundler_utils
local utils = {}

local insert = table.insert
local concat = table.concat

local function log_info(text)
    print('\27[36minfo\27[0m\tbundler: '..tostring(text))
end

local function log_error(text)
    print('\27[31merror\27[0m\tbundler: '..tostring(text))
end

function utils.get_lines(str)
    local lines = {}
    for line in str:gmatch("[^\n]+") do
        lines[#lines+1] = line
    end
    return lines
end

function utils.args_to_str(...)
    local args = {...}
    for k,v in next, args do
        args[k] = tostring(v)
    end
    return concat(args, ' ')
end

function utils.str_to_arr(str)
    local arr = {}
    for i=1, #str do
        arr[#arr+1] = str:sub(i,i)
    end
    return arr
end

function utils.char_arr_eq_str(arr, str, startindex)
    startindex = startindex or 0
    local chars = utils.str_to_arr(str)
    for i, char in next, chars do
        if arr[i+startindex] ~= char then
            return false
        end
    end
    return true
end

function utils.arr_splice(arr, startindex, endindex)
    local new_arr = {}
    local isExtractable = false
    for i, val in next, new_arr do
        if isExtractable then
            if i == endindex then
                isExtractable = false
            end
            new_arr[#new_arr+1] = val
        end
        if i == startindex then isExtractable = true end
    end
    return new_arr
end


---Helps with stripping certain code features.
utils.code_cleaner = {}
---Removes string wrappers off code (e.g.: "my_string" -> my_string)
---@param str string code line where the string is located
function utils.code_cleaner.rm_str(str)
    local str_opened_by = {fluffy=false, skinny=false}
    local new_chars = {}
    local chars = utils.str_to_arr(str)

    for i, char in next, chars do
        if chars[i-1] ~= '\\' and not str_opened_by.skinny and char == '"' then
            if str_opened_by.fluffy then
                str_opened_by.fluffy = false
            else
                str_opened_by.fluffy = true
            end
        elseif chars[i-1] ~= '\\' and not str_opened_by.fluffy and char == "'" then
            if str_opened_by.skinny then
                str_opened_by.skinny = false
            else
                str_opened_by.skinny = true
            end            
        else
            new_chars[#new_chars+1] = char
        end
    end

    return concat(new_chars, '')
end


local global_line_states = {withinMLComment = false,withinLongString = false}
---Strips comments off code
---@param line string
function utils.code_cleaner.rm_comments(line)
    local line_states = {withinLineComment = false,withinString = false,withinAltString = false}
    local line_chars = utils.str_to_arr(line)
    local char_array = {}

    local function isPendingClose()
        for _, v in next, line_states do
            if v == true then return true end
        end

        for _, v in next, global_line_states do
            if v == true then return true end
        end
    end

    local function isStringOpen()
        return line_states.withinString or line_states.withinAltString or global_line_states.withinLongString
    end

    for i, char in next, line_chars do
        if not isPendingClose() and not isStringOpen() then
            if char == '-' and line_chars[i+1] == '-' then
                if line_chars[i+2] == '[' then
                    global_line_states.withinMLComment = true
                else
                    line_states.withinLineComment = true
                end
            elseif char == '"' then
                line_states.withinString = true
            elseif char == "'" then
                line_states.withinAltString = true
            end

            if not global_line_states.withinMLComment and not line_states.withinLineComment then
                char_array[#char_array+1] = char
            end
        elseif isStringOpen() then
            if line_chars[i-1] ~= '\\' then
                if line_states.withinAltString and char == "'" then
                    line_states.withinAltString = false
                elseif line_states.withinString and char == '"' then
                    line_states.withinString = false
                end
            end
            char_array[#char_array+1]=char
        else
            if char == ']' and line_chars[i-1] == ']' then
                global_line_states.withinMLComment = false
            end
        end
    end

    return concat(char_array, '')
end

---Helps with extracting pieces of information from scripts.
utils.code_extractor = {}
---Extracts modules used within scripts.
---@param source string Source code of the script
---@param relative_path string Helps with resolving path
function utils.code_extractor.get_requires(source, relative_path)
    local invokation_lines = {}
    local char_groups = {}
    local modules = {}
    
    --log_info('scanning lines of "'.. relative_path ..'"')

    for _, line in next, utils.get_lines(source) do
        line = utils.code_cleaner.rm_comments(line)
        if line:match('require[(].-[)]') then
            invokation_lines[#invokation_lines+1] = line
        end
    end

    --log_info('stripping requires...')

    for ln, line in next, invokation_lines do
        local line_chars = utils.str_to_arr(line)
        local path_captured = {}
        local source_peek = {}
        local states = { opening = false, closing=false }

        for char_pos, char in next, line_chars do
            if not states.opening and utils.char_arr_eq_str(line_chars, 'require', char_pos-1) then
                states.opening = true
                source_peek[#source_peek+1] = char
            elseif states.opening and char == '(' then
                states.closing = true
                states.opening = false
                source_peek[#source_peek+1] = char
            elseif states.closing and char == ')' then
                states.closing = false
                source_peek[#source_peek+1] = char
                modules[#modules + 1] = {
                    module_path = utils.code_cleaner.rm_str(concat(path_captured, '')),
                    source_peek = concat(source_peek, ''),
                    script_path = relative_path,
                    line = ln,
                }
            elseif states.closing then
                path_captured[#path_captured+1] = char
                source_peek[#source_peek+1] = char
            elseif states.opening then
                source_peek[#source_peek+1] = char
            end
        end
    end

    return modules
end

---Helps with path releated actions.
utils.path = {}
---Converts a require path to a normal one (e.g.: .modules.mymodule)
---@param path string
function utils.path.lua_to_normal(path)
    local chars = utils.str_to_arr(path)

    for i, char in next, chars do
        if char == '.' and chars[i+1] == '.' then
            insert(chars, i+2, '/')
        elseif char == '.' and chars[i+1] ~= '/' then
            chars[i] = '/'
        end
    end

    return concat(chars, '')
end

---Simply checks if a file exists.
---@param path string
function utils.path.exists(path)
    local f = io.open(path, 'r')
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

---When a module is resolved, its contents are stored here.
utils.path._resolver_cached_contents = {}
---Attempts to find a compatible pathname for a module.
---@param module_path string
---@return table
function utils.path.resolve_module(module_path)
    local sequences = { module_path, module_path .. '/init.lua', module_path .. '.lua' }

    for _, pathname in next, sequences do
        local cache = utils.path._resolver_cached_contents[pathname]
        if cache ~= nil then return cache end
        if utils.path.exists(pathname) then
            local file = io.open(pathname, 'r')
            local contents  = file:read('*a')
            file:close()
            utils.path._resolver_cached_contents[pathname] = contents
            return {
                pathname = pathname,
                contents = contents
            }
        end
    end

    return {}
end

function utils.path.stat(path)
    local path_chars = utils.str_to_arr(path)
    local names = {}
    local cought = {}
    local state = { is_catching=false }

    for char_pos, char in next, path_chars do
        if char ~= '/' and char_pos == #path_chars and state.is_catching then
            cought[#cought+1] = char
        end
        
        if state.is_catching and char == '/' or char_pos == #path_chars then
            state.is_catching = false
            names[#names+1] = concat(cought, '')
            cought = {}
        end
        if not state.is_catching and char == '/' then
            state.is_catching = true
        else
            cought[#cought+1] = char
        end
    end

    return names
end

---Helps with interaction with files
utils.files = {}

---Creates a file (if non-existant) to the given directory,
---then writes the contents provided.
---@param dir string
---@param name string
---@param contents string
function utils.files.write(dir, name, contents)
    -- verify args
    assert(dir, 'Directory not set.')
    assert(name, 'File name not set.')
    assert(contents, 'Contents not set.')
    -- try to prevent error
    dir = utils.str_to_arr(dir)
    local lastchar = dir[#dir]
    if lastchar ~= '/' and lastchar ~= '\\' then
        dir[#dir+1] = '/'
    end
    dir = concat(dir, '')
    -- create file
    local pathname = dir .. name
    local file = io.open(pathname, 'w+')
    file:write(contents)
    file:close()
    return pathname
end


--- Helps to interact with the command line, mainly arguments passed to the script.
utils.cli = {}

--- This function returns the argument name and value if provided.
---
--- Format: main.lua -arg val
---@param arg_name string|number
---@return string|boolean
function utils.cli.get_arg(arg_name)
    --local arg = getfenv(2).arg
    if arg ~= nil then
        if type(arg_name) == 'number' then
            for i=1, #arg do
                local passed_arg_val = arg[i]
                if i == arg_name then
                    return passed_arg_val
                end
            end
        else
            for i, passed_arg_val in next, arg do
                local arg_chars = utils.str_to_arr(passed_arg_val)
                if utils.char_arr_eq_str(arg_chars, arg_name) then
                    return arg[i+1] or true
                end
            end
        end
    end
end

return utils