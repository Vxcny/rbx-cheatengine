--- @class utils
local utils = {}

-- Code
function utils.HttpClient()
    local self = {}
    self.client = getInternet()
    
    function self:get(url)
        return self.client.getURL(url)
    end

    function self:dispose()
        self.client.destroy()
    end
    
    return self
end

utils.process = {}

---@param processname string Name of process
---@return number
function utils.process.get_pid_by_name(processname)
    return getProcessIDFromProcessName(processname)
end

---Causes cheat engine to open the provided processname or processid.
---Note that if you provide an integer in the form of a string openProcess will look for a process that has as name the specified number. Provide an integer if you wish to specify the PID.
---@param processname string
---@overload fun(processid: number)
function utils.process.open(processname)
    return openProcess(processname)
end

return utils