local skynet = require "skynet"
local mysql = require "skynet.db.mysql"


local db = nil
local targetsoc = nil
local CMD = {}
function CMD.set(source, target)
	targetsoc = target
end

function CMD.save(source, user, text)
	db:query("insert into messages(source,text) values(\'" .. user .. "\',\'" .. text .. "\');")
end

function CMD.get(source, fd)
	local res = db:query("select * from messages")
	skynet.send(source, "lua", "send", fd, res)
end

skynet.start(function()
	print("sql start")
	db = mysql.connect({
		host = "127.0.0.1",
		port = 3306,
		database = "skynet",
		user = "root",
		password = "123.com",
		max_packet_size = 1024 * 1024,
		on_connect = nil
	})

	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd])
		f(source, ...)
	end)
end)
