--Loader: dofile([[C:\Users\USERNAME\Documents\rbx-cheatengine\bundler\bundle.lua]])
---@type utils
local utils = require('..src.ce-utils')


--- Memory Functions

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


--- Other

local function log_info(text)
    print('info: '..text)
end

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



for at=1, bytecode_size do
    local i = at - 1
    writeBytes(bytecode_loc + i, { bytecode_body:byte(at, at) })
end

writeInteger(bytecode_loc + bytecode_size + (bytecode_size + 4 % 4), bytecode_size)

c_ref1 = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
c_ref2 = { 0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15}


log_info('size of bytecode '.. addr_to_str(bytecode_size))
log_info('bytecode '.. addr_to_str(bytecode_loc))



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
local arg_data = utils.memory.shared_allocation(4096);

assert(arg_data, 'Failed to allocate shared memory...')

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

---Handles external calls of convention routines.
---Converts every function to an stdcall unless they are already.
---@param func function
---@param convention string
---@param args number
function make_stdcall(func, convention, args)
    if convention == 'stdcall' then
        return func
    end

    local ret = args * 4
    nfunctions = nfunctions + 1
    local loc = utils.memory.allocate(4096)

    local code = utils.classes.StringBuffer()
    code:write(addr_to_str(loc)..": \n")
    code:write("push ebp \n")
    code:write("mov ebp,esp \n")
    code:write("push eax \n")

    if convention == 'cdecl' then
        for i=args, 1, -1 do
            -- since cheat engine's executeCode (a.k.a. CreateRemoteThread)
            -- can only pass 1 arg to a function, we can compensate
            -- by passing all of our args through variables in memory.
            -- We can spawn a thread for each function call as this
            -- only needs 2 function calls to work.
            --
            code:write("push ["..addr_to_str(arg_data+((i-1)*4)).."] \n") --"push "..args--"push [ebp+"..to_str(4+(i*4)).."] \n";
        end
    elseif convention == 'thiscall' then
        if (args > 1) then
            for i=args,2,-1 do
                code:write("push ["..addr_to_str(arg_data+((i-1)*4)).."] \n") --"push [ebp+"..to_str(4+(i*4)).."] \n";
	    end
        end
        if (args > 0) then
            code:write("push ecx \n");
            code:write("mov ecx,["..addr_to_str(arg_data+0).."] \n") --"mov ecx,[ebp+8] \n";
            ret = ret - 4;
        end
    elseif convention == 'fastcall' then
        if (args > 2) then
            for i=args,3,-1 do
                code:write("push ["..addr_to_str(arg_data+((i-1)*4)).."] \n") --"push [ebp+"..to_str(4+(i*4)).."] \n";
	    end
        end
        if (args > 0) then
            code:write("push ecx");
            code:write("mov ecx,["..addr_to_str(arg_data+0).."] \n") --"mov ecx,[ebp+8] \n";
            ret = ret - 4;
        end
	    if (args > 1) then
            code:write("push edx");
            code:write("mov ecx,["..addr_to_str(arg_data+4).."] \n") --"mov edx,[ebp+8] \n";
            ret = ret - 4;
        end
    end

    --------
    code:write('call' .. addr_to_str(func) .. '\n')
    code:write('mov [' .. addr_to_str(arg_data + 64) .. '],eax \n')

    if (convention == "cdecl") then
        code:write("add esp,".. byte_to_str(args*4).." \n")
    elseif (convention == "thiscall") then
        code:write("pop ecx \n")
    elseif (convention == "fastcall") then
        code:write("pop ecx \n")
        code:write("pop edx \n")
    end

    code:write("pop eax \n")
    code:write("pop ebp \n")
    code:write("ret 04")
    --------

    utils.actions.auto_assemble(code);
    return loc;
end

function patch_retcheck(func_start)
    local func_end = get_next_prologue(func_start + 3);
    local func_size = func_end - func_start;

    nfunctions = nfunctions + 1;
    local func = utils.memory.allocate(func_size);
    writeBytes(func, readBytes(func_start, func_size, true));

    for i = 1,func_size,1 do
        local at = func + i;
        if (read_byte(at) == 0x72 and read_byte(at + 2) == 0xA1 and read_byte(at + 7) == 0x8B) then
            write_byte(at, 0xEB);
            log_info("Patched retcheck at "..addr_to_str(at))
            break;
        end
    end

    local i = 1;
    while (i < func_size) do
        -- Fix relative calls
        if (read_byte(func + i) == 0xE8 or read_byte(func + i) == 0xE9) then
            local oldrel = readInteger(func_start + i + 1);
            local relfunc = (func_start + i + oldrel) + 5;

            if (relfunc % 16 == 0 and relfunc > base and relfunc < base + 0x3FFFFFF) then
                local newrel = relfunc - (func + i + 5);
                writeInteger((func + i + 1), newrel);
                i = i + 4;
            end
        end
        i = i + 1;
    end

    -- store information about this de-retchecked function
    table.insert(functions,{func,func_size});
    return func;
end


local args_at = 0
function setargs(t)
    args_at = 0
    for i=1,#t do
        writeInteger(arg_data + args_at, t[i]);
        args_at = args_at + 4;
    end
end


-- [[
    print("");
    log_info("deserializer: "..addr_to_str((r_deserialize - base) + 0x400000));
    log_info("spawn: "..addr_to_str((r_spawn - base) + 0x400000));
    log_info("lua_gettop: "..addr_to_str((r_gettop - base) + 0x400000));
    log_info("lua_newthread: "..addr_to_str((r_newthread - base) + 0x400000));
    print("");
-- ]]

-- update our functions to suit their calling conventions
-- and bypass retcheck if there is a retcheck
r_deserialize = make_stdcall(r_deserialize, "cdecl", 4);
r_spawn = make_stdcall(r_spawn, "cdecl", 1);
r_newthread = make_stdcall(patch_retcheck(r_newthread), "cdecl", 1);

log_info("r_deserialize: "..addr_to_str(r_deserialize));
log_info("r_spawn: "..addr_to_str(r_spawn));
log_info("r_newthread: "..addr_to_str(r_newthread));

local chunkName = (arg_data + 128);
writeString(chunkName, "=Script1");
writeInteger(chunkName + 12, 8); -- string length


log_info("chunkName: " .. addr_to_str(chunkName));
log_info("gettop: " .. addr_to_str(r_gettop));


-- place the hook for gettop
writeBytes(r_gettop + 6, gettop_hook);


-- wait for lua state
t = createTimer(nil)


function checkHook(timer)
    if (rL == 0) then
        -- occur one time
        rL = readInteger(trace_loc);
        if (rL ~= 0) then
            timer_setEnabled(t, false);
            
            -- restore bytes
            writeBytes(r_gettop + 6, gettop_old_bytes);

            print("Lua state: " ..addr_to_str(rL));

            setargs({rL, chunkName, bytecode_loc, bytecode_size});
            executeCode(r_deserialize);
            executeCode(r_spawn); -- uses rL from last setargs call ...
        end
    end
end


timer_setInterval(t, 100);
timer_onTimer(t, checkHook);
timer_setEnabled(t, true);
