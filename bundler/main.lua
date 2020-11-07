--[[
    Author: SoundInfinity
    Date: 11/04/2020
]]

---@type bundler_utils
local utils = require('.utils')


local function log_info(text)
    print('\27[36minfo\27[0m\tbundler: '..tostring(text))
end

local function log_error(text)
    print('\27[31merror\27[0m\tbundler: '..tostring(text))
end

local concat = table.concat
local remove = table.remove
local insert = table.insert

local function fix_path(import_path)
    local chars = utils.str_to_arr(import_path)
    for i, char in next,chars do
        if char == '.' and chars[i+1] == '.' then
            insert(chars, i+2, '/')
        elseif char == '.' and chars[i+1] ~= '/' then
            chars[i] = '/'
        end
    end
    return concat(chars, '')
end


local loaded = {}

function intercept_requires(base_dir, script_file)
    if (base_dir .. script_file):match('^'..base_dir..base_dir) then base_dir = '' end
    local module_file = utils.path.resolve_module(base_dir .. script_file)

    local data = {
        script_file = script_file,
        script_path = module_file.pathname, --mod
        contents = module_file.contents, --mod
        base_dir = base_dir,
        required_at = '0:0',
        imports = {}
    }

    if module_file.pathname then
        if loaded[module_file.pathname] then
            return data
        else
            loaded[module_file.pathname] = true
        end
    end

    if module_file.contents then
        --get_requires
        for _, module in next, utils.code_extractor.get_requires(module_file.contents, module_file.pathname) do
            local dependency = intercept_requires(base_dir, utils.path.lua_to_normal(module.module_path))
            insert(data.imports, {
                dependant = module_file.pathname,
                namecall = module.module_path,
                source = dependency.contents,
                path = dependency.script_path
            })

            for _, submodule in next, dependency.imports do
                insert(data.imports, submodule)
            end
        end
    else
        log_error(('module path "%s" not found.'):format(script_file))
    end

    return data
end

local function StringBuffer(initial_str)
    local self = {}
    local insert = table.insert
    local concat = table.concat
    self.characters = {}

    function self:write(str)
        for i=1, #str do
            insert(self.characters, str:sub(i, i))            
        end
    end

    function self:tostring()
        return concat(self.characters, '')
    end

    if initial_str then self:write(initial_str) end

    return self
end
--[[
local function write_file(file_dir, file_name, contents)
    if file_dir ~= nil then
        file_dir = utils.str_to_arr(file_dir)
        local lastchar = file_dir[#file_dir]
        if lastchar ~= '/' or lastchar ~= '\\' then
            insert(file_dir, '/')
        end
        file_dir = concat(file_dir, '')
    else
        file_dir = ''
    end
    
    local filepath = file_dir .. file_name
    local file = io.open(filepath, 'w+')
    file:write(contents)
    file:close()

    return filepath
end
]]
local fileMinifier = require('.minify')

local function minify_code(code)
    local success, message = pcall(function()
        return fileMinifier.minify(code)
    end)

    if success then
        return message
    else
        return false
    end
end

local minify_files = utils.cli.get_arg('-minify')

local function clean_code(code)
    local lines = utils.get_lines(code)
    for ln, line in next, lines do
        lines[ln] = utils.code_cleaner.rm_comments(line)
    end
    return concat(lines, ' ')
end

function bundle(dir, file, outdir, outfile)
    log_info('working...')
    local bundle_source = StringBuffer()
    local entry = intercept_requires(dir, file)
    local funcs = {entry=entry.contents}

    for _, module_info in next, entry.imports do
        funcs[module_info.namecall] = module_info.source
    end

    bundle_source:write("(function() local modules = {} local require = function(module) return modules[module]() end ")
    bundle_source:write(" modules = {")

    for namecall, source in next, funcs do
        local doDefault = true
        --Clean Code
        local cleaned_source = clean_code(source)
        --Minify files
        if minify_files ~= nil then
            local minified = minify_code(cleaned_source)
            if minified then
                bundle_source:write(('["%s"] = function() %s end,'):format(namecall, minified))
                doDefault = false
            end
        end
        --Do Default
        if doDefault then
            bundle_source:write(('["%s"] = function() %s end,'):format(namecall, cleaned_source))
        end
    end
    
    bundle_source:write('} ')
    bundle_source:write(" modules.entry() end)()")

    local filepath = utils.files.write(outdir, outfile, bundle_source:tostring()) 
    log_info('output file at "' .. filepath ..'"')
    return filepath
end

local options = {
    basedir = '../src/',
    filename = 'main.lua',
    outdir = './',
    outfile = 'bundle.lua'
}

local input_file = utils.cli.get_arg('-f') or utils.cli.get_arg('-file')
local output_path_dir = utils.cli.get_arg('-o') or utils.cli.get_arg('-output-path')

if output_path_dir then
    options.outdir = output_path_dir 
end

if input_file then
    options.outfile = input_file 
end

local bundle_path = bundle(options.basedir, options.filename, options.outdir, options.outfile)