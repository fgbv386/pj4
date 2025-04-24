local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"
local conns = {}
local players = {}

function conn()
	local m = {
		fd = nil,
		player = nil,
	}
	return m
end

function gateplayer()
	local m = {
		playerid = nil,
		agent = nil,
		conn = nil,
	}
	return m
end

local str_unpack = function(msgstr)
	local msg = {}

	while true do
		local arg, rest = string.match(msgstr, "(.-),(.*)")
		if arg then
			msgstr = rest
			table.insert(msg, arg)
		else
			table.insert(msg, msgstr)
			break
		end
	end
	return msg[1], msg
end

local str_pack = function(cmd, msgstr)
	return table.concat(msgstr, ",") .. "$"
end

local process_msg = function(fd, msgstr)
	local cmd, msg = str_unpack(msgstr)
	skynet.error("recv" .. fd .. "[" .. cmd .. "] {" .. table.concat(msg, ",") .. "}")

	local conn = conns[fd]
	local playerid = conn.playerid

	if not playerid then
		local node = skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1, #nodecfg.login)
		local login = "login" .. loginid
		skynet.send(login, "lua", "client", fd, cmd, msg)
	else
		local gplayer = players[playerid]
		local agent = gplayer.agent
		skynet.send(agent, "lua", "client", cmd, msg)
	end
end

local process_buff = function(fd, readbuff)
	while true do
		local msgstr, rest = string.match(readbuff, "(.-)$(.*)")
		if msgstr then
			readbuff = rest
			process_msg(fd, msgstr)
		else
			return readbuff
		end
	end
end



s.resp.send_by_fd = function(sourse, fd, msg)
	if not conns[fd] or msg == nil then
		return
	end
	skynet.error("waiting pack msg")
	local buff = str_pack(msg[1], msg)
	skynet.error("send" .. fd .. "[" .. msg[1] .. "] {" .. table.concat(msg, ",") .. "}")
	socket.write(fd, buff)
end

s.resp.send = function(sourse, playerid, msg)
	local gplayer = players[playerid]
	if gplayer == nil then
		return
	end
	local c = gplayer.conn
	if c == nil then
		return
	end

	s.resp.send_by_fd(nil, c.fd, msg)
end

s.resp.sure_agent = function(sourse, fd, playerid, agent)
	local conn = conns[fd]
	if not conn then
		skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登陆即下线")
		return false
	end
	print("preparing")
	conn.playerid = playerid

	local gplayer = gateplayer()
	gplayer.playerid = playerid
	gplayer.agent = agent
	gplayer.conn = conn
	players[playerid] = gplayer

	return true
end
local disconnect = function(fd)
	local c = conns[fd]
	if not c then
		return
	end

	local playerid = c.playerid

	if not playerid then
		return
	else
		players[playerid] = nil
		local reason = "断线"
		skynet.send("agentmgr", "lua", "reqkick", playerid, reason)
	end
end

s.resp.kick = function(sourse, playerid)
	local gplayer = players[playerid]
	if not gplayer then
		return
	end

	local c = gplayer.conn
	players[playerid] = nil

	if not c then
		return
	end
	conns[c.fd] = nil
	disconnect(c.fd)
	socket.close(c.fd)
end

local recv_loop = function(fd)
	socket.start(fd)
	skynet.error("socket connected " .. fd)
	local readbuff = ""
	while true do
		local recvstr = socket.read(fd)
		print(recvstr)
		if recvstr then
			readbuff = readbuff .. recvstr
			readbuff = process_buff(fd, readbuff)
		else
			skynet.error("socket close" .. fd)
			disconnect(fd)
			socket.close(fd)
			return
		end
	end
end

local connect = function(fd, addr)
	print("connect from " .. addr .. " " .. fd)
	local c = conn()
	conns[fd] = c
	c.fd = fd
	skynet.fork(recv_loop, fd)
end

function s.init()
	local node = skynet.getenv("node")
	local nodecfg = runconfig[node]
	local port = nodecfg.gateway[s.id].port

	local listenfd = socket.listen("0.0.0.0", port)
	skynet.error("Listen socket :", "0.0.0.0", port)
	socket.start(listenfd, connect)
end

s.start(...)
