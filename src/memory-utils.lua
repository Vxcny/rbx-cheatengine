local function read_byte(addr)
    return readBytes(addr, 1, false)
end

local function write_byte(addr, byte)
    writeBytes(addr, { byte })
end

local function byte_to_str(byte) --Alt of "to_str"
    if byte == nil then return "00" end
    local str=""
    if byte <= 256 then
        str=str..c_ref1[math.floor(byte/16)+1]
        str=str..c_ref1[math.floor(byte%16)+1]
    end
    return str
end

local function addr_to_bytes(addr)
    assert(addr~=nil, 'Nil address used in addr_to_bytes')
    local bytes = {0,0,0,0}
    
    for i=0,3 do
        bytes[3-i]=(addr>>(i*8))%256
    end
    return bytes
end

local function addr_to_str(addr)
    assert(addr~=nil, 'Nil address used in addr_to_str')
    local str="";
    local bytes = addr_to_bytes(addr)
    for i=0,3 do -- lua tables
        str = str..byte_to_str(bytes[i])
    end
    return str
end

local function str_to_hex(str)
    if (string.len(str) ~= 2) then
        return 0
    end
    local byte=0
    for i=1,16,1 do
        if (str:sub(1,1)==c_ref1[i]) then
            byte=byte+(c_ref2[i]*16)
        end
        if (str:sub(2,2)==c_ref1[i]) then
            byte=byte+i
        end
    end
    return byte
end

local function readsb(addr, len) --TODO: Rename;Idk what "sb" is :|
    local str = ""
    for i=1,len do
        str=str..byte_to_str(read_byte(addr))
    end
    return str
end

local function get_prologue(addr)
    local func_start = addr;
    while not (read_byte(func_start) == 0x55 and read_byte(func_start + 1) == 0x8B and read_byte(func_start + 2) == 0xEC) do
        func_start = func_start - 1;
    end
    return func_start;
end

local function get_next_prologue(addr)
    local func_start = addr;
    while not (read_byte(func_start) == 0x55 and read_byte(func_start + 1) == 0x8B and read_byte(func_start + 2) == 0xEC) do
        func_start = func_start + 1;
    end
    return func_start;
end

return {
    read_byte = read_byte,
    write_byte = write_byte,
    byte_to_str = byte_to_str,
    addr_to_str = addr_to_str,
    addr_to_bytes = addr_to_bytes,
    str_to_hex = str_to_hex,
    readsb = readsb,
    get_prologue = get_prologue,
    get_next_prologue = get_next_prologue,
}