local Config = {}

local config = {
	debug = false,
}

function Config.get()
	return config
end

function Config.setDebug(enabled: boolean)
	config.debug = enabled
end

function Config.isDebugEnabled(): boolean
	return config.debug
end

return Config
