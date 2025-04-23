local skynet = require "skynet"

skynet.start(function()
	print("m start")
	local s = skynet.newservice("soc")
	local q = skynet.newservice("sql")

	skynet.send(s, "lua", "set", q)
	skynet.send(q, "lua", "set", s)

	--skynet.exit()
end)
