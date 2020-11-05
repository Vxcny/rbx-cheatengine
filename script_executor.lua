(function(args)
local modules = {}
modules['../src/main.lua'] = function(...)
require('..src.utils')

print(HttpClient())end
function import(n)
return modules[n](table.unpack(args))
end
local entry = import('../src/main.lua')
end)({...})