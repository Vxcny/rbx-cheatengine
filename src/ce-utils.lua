--- @class utils
local utils = {}

utils.http = {}

---@param url string
function utils.http.get(url)
    local client = getInternet()
    local response = client.getURL(url)
    client.destroy()
    return response
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

utils.memory = {}

---@param size number Size of allocation
function utils.memory.allocate(size, ...)
    return allocateMemory(size, ...)
end

utils.addresses = {}

---Passes the given string to Cheat Engine's symbol handler and returns the corresponding address as an integer. Can be a module name or an export. Set local to true if you wish to query the symbol table of the CE process.
---If errorOnLookupFailure is set to true (the default value), if you look up a symbol that does not exist, it will throw an error. With errorOnLookupFailure set to false, it will return 0.
---@param addr_str string The AddressString to convert to an integer
---@param _local number Set to true if you wish to query the symbol table of the CE process
---@return number
function utils.addresses.get(addr_str, _local)
    return getAddress(addr_str, _local)
end

return utils