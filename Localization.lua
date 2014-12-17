
local addon, ns = ...

ns.L = setmetatable({},{__index=function(t,k)
	local v = tostring(k)
	rawset(t,k,v)
	return v
end})

