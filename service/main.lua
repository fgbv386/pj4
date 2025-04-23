local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
skynet.start(function()
	local mynode = skynet.getenv("node")
	local nodecfg = runconfig[mynode]

	local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
	skynet.name("nodemgr", nodemgr)

	cluster.reload(runconfig.cluster)
	cluster.open(mynode)

	for i, v in pairs(nodecfg.gateway or {}) do
		local srv = skynet.newservice("gateway", "gateway", i)
		skynet.name("gateway" .. i, srv)
	end
	for i, v in pairs(nodecfg.login or {}) do
		local srv = skynet.newservice("login", "login", i)
		skynet.name("login" .. i, srv)
	end

	local anode = runconfig.agentmgr.node

	if mynode == anode then
		print("c")
		local srv = skynet.newservice("agentmgr", "agentmgr", 0)
		print("111")
		skynet.name("agentmgr", srv)
	else
		local proxy = cluster.proxy(anode, "agentmgr")
		skynet.name("agentmgr", proxy)
	end

	skynet.exit()
end)
