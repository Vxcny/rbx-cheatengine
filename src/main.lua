--Loader: dofile([[C:\Users\USERNAME\Documents\rbx-cheatengine\bundler\bundle.lua]])
---@type utils
local utils = require('..src.ce-utils')
local mem_utils = require('..src.memory-utils')

local read_byte = mem_utils.read_byte
local write_byte = mem_utils.write_byte
local byte_to_str = mem_utils.byte_to_str
local addr_to_str = mem_utils.addr_to_str
local addr_to_bytes = mem_utils.addr_to_bytes
local str_to_hex = mem_utils.str_to_hex
local readsb = mem_utils.readsb
local get_prologue = mem_utils.get_prologue
local get_next_prologue = mem_utils.get_next_prologue

local roblox_pid = utils.process.get_pid_by_name("RobloxPlayerBeta.exe")
utils.process.open(roblox_pid)

-- TODO: New varname
local base = utils.addresses.get(enumModules(roblox_pid)[1].Name)
local functions = {}
local nfunctions = 0

local bytecode_body = utils.http.get("https://raw.githubusercontent.com/thedoomed/Cheat-Engine/master/bytecode_example.bin")

local bytecode_size = string.len(bytecode_body)
local bytecode_loc = utils.memory.allocate(bytecode_size)
local bytecode = {}

for i=1, bytecode_size do
    writeBytes(bytecode_loc + (i-1), { bytecode_body:byte(i, i) })
end

writeInteger(bytecode_loc + bytecode_size + (bytecode_size + (4%4)), bytecode_size)

c_ref1 = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
c_ref2 = { 0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15}


local function log_info(text)
    print('executor: '..text)
end



log_info('bytecode size: '.. addr_to_str(bytecode_size))
log_info('bytecode: '.. addr_to_str(bytecode_loc))



-- Search for an XREF of the string
-- "Spawn function requires 1 argument"...
-- since scanning the string's address will take us
-- to the spawn function (this is how an XREF works
-- in IDA Pro)
-- 
local str_spawn_ref = addr_to_bytes(utils.addresses.get(AOBScan("537061776E20","-C-W",0,"")[0])); 
-- address of the string "Spawn " . . .
local str_spawn_bytes = byte_to_str(str_spawn_ref[3])..byte_to_str(str_spawn_ref[2])..byte_to_str(str_spawn_ref[1])..byte_to_str(str_spawn_ref[0]);

-- scan for all of the addresses
local r_spawn       = utils.addresses.get(AOBScan(str_spawn_bytes,"-C-W",0,"")[0]);
local r_deserialize = utils.addresses.get(AOBScan("0F????83??7FD3??83??0709","-C-W",0,"")[0]);
local r_gettop      = utils.addresses.get(AOBScan("558BEC8B??088B????2B??????????5DC3","-C-W",0,"")[0]);
local r_newthread   = utils.addresses.get(AOBScan("72??6A01??E8????????83C408??E8","-C-W",0,"")[0]);

r_deserialize      = get_prologue(r_deserialize);
r_spawn            = get_prologue(r_spawn);
r_newthread        = get_prologue(r_newthread);

-- a place to store our function information
-- for external function calls
--
local arg_data = allocateSharedMemory(4096);
assert(arg_data~=nil, 'Failed to allocate shared memory...')

local ret_location = (arg_data + 64);

function getReturn()
    return readInteger(ret_location);
end

-- lua state hook
local rL = 0;
local gettop_old_bytes = readBytes(r_gettop + 6, 6, true);

-- we will borrow a tiny section of the
-- allocated memory for function data
-- to place our state hooking code at
local gettop_hook_loc = arg_data + 0x400;
local hook_at = gettop_hook_loc;
local trace_loc = arg_data + 0x3FC;

local jmp_pointer_to = arg_data + 0x3F8;
local jmp_pointer_back = arg_data + 0x3F4;

writeInteger(jmp_pointer_to, gettop_hook_loc);
writeInteger(jmp_pointer_back, r_gettop + 12); -- jmpback / return

writeBytes(hook_at,	{ 0x60, 0x89, 0x0D });	hook_at = hook_at + 3;
writeInteger(hook_at, 	trace_loc);		hook_at = hook_at + 4;
write_byte(hook_at,	0x61);			hook_at = hook_at + 1;
writeBytes(hook_at,	gettop_old_bytes); 	hook_at = hook_at + 6;
writeBytes(hook_at,	{ 0xFF, 0x25 }); 	hook_at = hook_at + 2;
writeInteger(hook_at, 	jmp_pointer_back);

-- insert a jmp instruction
bytes_jmp = addr_to_bytes(jmp_pointer_to);
local gettop_hook = { 0xFF, 0x25, bytes_jmp[3], bytes_jmp[2], bytes_jmp[1], bytes_jmp[0] };

log_info("gettop hook: " .. addr_to_str(gettop_hook_loc))