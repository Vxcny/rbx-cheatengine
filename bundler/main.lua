--[[
    Author: SoundInfinity
    Date: 11/04/2020
]]

local function get_lines(text)
    local lines = {}
    
    for line in text:gmatch("[^\n]+") do
        lines[#lines+1] = line
    end
    return lines
end

local concat = table.concat
local remove = table.remove
local insert = table.insert

local function string_to_array(str)
    local array = {}
    for char in str:gmatch('.') do insert(array, char) end
    return array
end

local global_line_states = {withinMLComment = false,withinLongString = false}

local function remove_comments(line)
    local line_states = {withinLineComment = false,withinString = false,withinAltString = false}
    local line_chars = string_to_array(line)
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
                insert(char_array, char)
            end
        elseif isStringOpen() then
            if line_chars[i-1] ~= '\\' then
                if line_states.withinAltString and char == "'" then
                    line_states.withinAltString = false
                elseif line_states.withinString and char == '"' then
                    line_states.withinString = false
                end
            end
            insert(char_array, char)
        else
            if char == ']' and line_chars[i-1] == ']' then
                global_line_states.withinMLComment = false
            end
        end
    end

    return table.concat(char_array, '')
end

local function char_arr_eq_str(arr, str, startindex)
    startindex = startindex or 0
    local chars = string_to_array(str)
    for i, char in next, chars do
        if arr[i+startindex] ~= char then
            return false
        end
    end
    return true
end

local function char_arr_splice(arr, startindex, endindex)
    local chars = {}
    local isExtractable = false
    for i, char in next, arr do
        if isExtractable then
            if i == endindex then
                isExtractable = false
            end
            insert(chars, char)
        end
        if i == startindex then isExtractable = true end
    end
    return chars
end

local function get_requires(source)
    local require_lines = {}

    for _, line in next, get_lines(source) do
        line = remove_comments(line)
        if (line:match('require[(].-[)]')) then
            require_lines[#require_lines+1] = line
        end
    end

    local requires = {}
    for _, require_str in next, require_lines do
        local line_chars = string_to_array(require_str)
        -- local requires = {}
        local isRequireOpening = false
        local isRequireClosing = false

        for i, char in next, line_chars do
            if not isRequireOpening and char_arr_eq_str(line_chars, 'require', i-1) then
                isRequireOpening = true
                insert(requires, {})
            elseif isRequireOpening and char == '(' then
                isRequireClosing  = true
                isRequireOpening  = false
            elseif isRequireClosing and char == ')' then
                isRequireClosing  = false
            elseif isRequireClosing then
                insert(requires[#requires], char)
            end
        end

    end
    
    for k,v in next, requires do
        requires[k] = concat(v, '')
    end


    return requires
end

local function remove_string(str)
    local chars = string_to_array(str)
    local str_open = {fluffy=false,skinny=false}
    local new_chars = {}

    local function isOpen()
        for _, v in str_open do
            if v then return true end
        end
    end 


    for i, char in next, chars do
        if chars[i-1] ~= '\\' and not str_open.skinny and char == '"' then
            if str_open.fluffy then
                str_open.fluffy = false
            else
                str_open.fluffy = true
            end
        elseif chars[i-1] ~= '\\' and not str_open.fluffy and char == "'" then
            if str_open.skinny then
                str_open.skinny = false
            else
                str_open.skinny = true
            end            
        else
            insert(new_chars, char)
        end
    end

    return concat(new_chars, '')
end

local path = {}

local function fix_path(import_path)
    local chars = string_to_array(import_path)
    for i, char in next,chars do
        if char == '.' and chars[i+1] == '.' then
            insert(chars, i+2, '/')
        elseif char == '.' and chars[i+1] ~= '/' then
            chars[i] = '/'
        end
    end
    return concat(chars, '')
end

local pathnames = {}

local cached_contents = {}

function get_module(pathname)
    local paths = {pathname, pathname .. '/init.lua', pathname .. '.lua'}

    for _, path in next, paths do
        if cached_contents[path] then return path, cached_contents[path] end
        local file = io.open(path)
        if file then
            local contents = file:read'*a'
            file:close()
            cached_contents[path] = contents
            return path, contents
        end
    end 
end

local loaded = {}
function intercept_requires(base_dir, script_file)
    if (base_dir .. script_file):match('^'..base_dir..base_dir) then base_dir = '' end
    local path, contents = get_module(base_dir .. script_file)
    local data = {
        script_file = script_file, script_path = path,
        contents = contents, base_dir = base_dir,
        imports = {}
    }

    if loaded[path] then
        return data
    else
        loaded[path] = true
    end

    for _, module in next, get_requires(contents) do
        local dependency = intercept_requires(base_dir, fix_path(remove_string(module)))
        insert(data.imports, {
            dependant = path,
            namecall = remove_string(module),
            source = dependency.contents,
            path = dependency.script_path
        })

        for _, submodule in next, dependency.imports do
            insert(data.imports, submodule)
        end
    end

    return data
end



function bundle(dir, file, outdir)
    local funcs = {}
    local bundle_source = ""
    local entry = intercept_requires(dir, file)

    for _, module_info in next, entry.imports do
        funcs[module_info.namecall] = module_info.source
    end
    
    
    funcs['entry'] = entry.contents
    bundle_source = bundle_source .. "(function() local modules = {}\nlocal require = function(module) return modules[module]() end\n"
    bundle_source = bundle_source .. " modules = {"

    for namecall, source in next, funcs do
        local lines = get_lines(source)
    
        for i,v in next, lines do lines[i] = remove_comments(v) end
    
        bundle_source = bundle_source .. '["'..namecall..'"] = function() '.. concat(lines, ' ') .. ' end,'
    end
    
    bundle_source = bundle_source .. '}\n'
    bundle_source = bundle_source .. "\nmodules.entry()\nend)()"
    
    if outdir then
        outdir = string_to_array(outdir)
        local lastchar = outdir[#outdir]
        if lastchar ~= '/' or lastchar ~= '\\' then
            insert(outdir, '/')
        end
        outdir = concat(outdir, '')
    else
        outdir = ''
    end
    
    local filepath = outdir .. 'bundle.lua'
    local file = io.open(filepath, 'w+')
    file:write(bundle_source)
    file:close()

    return filepath
end

function minify(path)
    io.popen('lua ./minify.lua minify ' .. path .. ' > bundle.min.lua')
end
bundle('../src/', 'main.lua')
-- minify(b)