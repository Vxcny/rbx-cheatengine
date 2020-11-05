(function() local modules = {}
local require = function(module) return modules[module]() end
 modules = {["entry"] = function() local other = require('..src.folder.test') local utils = require('..src.utils') utils.HttpClient():get("https://pastebin.com/raw/G620b8Vu") end,["..src.folder.test"] = function()  end,["..src.utils"] = function() local utils = {}  function utils.HttpClient()     local self = {}     self.client = getInternet()          function self:get(url)         print('wants: '..url)         return self.client.getURL(url)     end     function self:dispose()         self.client.destroy()     end          return self end function utils.Process()     local self = {}     return self end return utils end,}

modules.entry()
end)()