---@class utils
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
function utils.memory.allocate(size)
    return allocateMemory(size)
end


---Creates a shared memory object of the given size if it doesn't exist yet. If size is not given and there is no shared region with this name then the default size of 4096 is used
---It then maps this shared memory block into the currently targeted process. It returns the address of mapped region in the target process
---When the process closes, you can target another process and allocate the same block on there again. Then you can read the state before the process closed
---@param name	string	The name of the block to allocate
---@param size	number	The prefered size of the allocated block

function utils.memory.shared_allocation(name, size)
    return allocateSharedMemory(name)
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

utils.classes = {}

---@class StringBuffer
---@field characters table
---@field write fun(str: string): nil
---@field tostring fun(): string

---@return StringBuffer
function utils.classes.StringBuffer(initial_str)
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


function utils.classes.Timer(owner, enabled)
    -- TODO: https://wiki.cheatengine.org/index.php?title=Lua:Class:Timer
end


utils.actions = {}
function utils.actions.auto_assemble(code)
    return autoAssemble(code)
end


return utils