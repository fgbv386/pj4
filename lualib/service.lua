local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
	name = "",
	id = 0,

	exit = nil,
	init = nil,

	resp = {},
}



function traceback(err)
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end

local dispatch = function(session, adddress, cmd, ...)
	local fun = M.resp[cmd]
	if not fun then
		skynet.ret()
		return
	end

	local ret = table.pack(xpcall(fun, traceback, adddress, ...))
	local isok = ret[1]

	if not isok then
		skynet.ret()
		return
	end

	skynet.retpack(table.unpack(ret, 2))
end

function init()
	skynet.dispatch("lua", dispatch)
	if M.init then
		M.init()
	end
end

function M.start(name, id, ...)
	M.name = name
	M.id = tonumber(id)
	skynet.start(init)
end

function M.call(node, srv, ...)
	local mynode = skynet.getenv("node")
	if node == mynode then
		return skynet.call(srv, "lua", ...)
	else
		return cluster.call(node, srv, ...)
	end
end

function M.send(node, srv, ...)
	local mynode = skynet.getenv("node")
	if node == mynode then
		return skynet.send(srv, "lua", ...)
	else
		return cluster.send(node, srv, ...)
	end
end

return M
