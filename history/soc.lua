local skynet = require "skynet"
local socket = require "skynet.socket"

local targetsql = nil
local CMD = {}
local clients = {}

function testmes(mes)
	local usr, psd = string.match(mes, "([^:]+):([^:]+)")
	if usr ~= nil and psd ~= nil then
		print("true:" .. usr .. ":" .. psd)
		return true, usr, psd
	end
	print("false")
	return false, nil, nil
end

function connect(fd, addr)
	print(fd .. "connect:" .. addr)
	socket.start(fd)
	clients[fd] = {}
	clients[fd]["log"] = false
	while true do
		local readdata = socket.read(fd)
		if readdata ~= nil and readdata ~= false then
			print(readdata)
			if clients[fd]["log"] == true then
				for i, v in pairs(clients) do
					if v["log"] == true and v["usr"] ~= clients[fd]["usr"] then
						socket.write(i, clients[fd]["usr"] .. ":" .. readdata)
					end
				end
				if readdata == "get" then
					skynet.send(targetsql, "lua", "get", fd)
				else
					skynet.send(targetsql, "lua", "save", clients[fd]["usr"], readdata)
				end
			else
				clients[fd]["log"], clients[fd]["usr"], clients[fd]["psd"] = testmes(readdata)
			end
		else
			print(fd .. "closed")
			clients[fd] = nil
			socket.close(fd)
			break
		end
	end
end

function CMD.set(source, target)
	targetsql = target
end

function CMD.send(source, fd, res)
	if res == nil then
		return
	end
	for i, v in pairs(res) do
		socket.write(fd, v.source .. ":" .. v.text .. "\n")
	end
end

skynet.start(function()
	print("soc start")
	local listenfd = socket.listen("0.0.0.0", 8888)
	socket.start(listenfd, connect)
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd])
		f(source, ...)
	end)
end)
