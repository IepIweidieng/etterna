local returnFunction, level = ...;
if not returnFunction then
	return Def.Actor{
		Name = "New Actor",
	};
end


local function doPreProcess(actor, actorDef, level) end


local attrs_mt = {};
local function simpleMergeTables(lhs, rhs)
	local ret = {};
	for key, value in pairs(lhs) do
		ret[key] = value;
	end

	for key, value in pairs(rhs) do
		ret[key] = value;
	end
	
	setmetatable(ret, attrs_mt);
	return ret;
end
attrs_mt = {__concat = simpleMergeTables;};

local attrs = {
	Name = 0,
	BaseRotationX = 0,
	BaseRotationY = 0,
	BaseRotationZ = 0,
	BaseZoomX = 0,
	BaseZoomY = 0,
	BaseZoomZ = 0,
};

setmetatable(attrs, attrs_mt);


return attrs, doPreProcess;
