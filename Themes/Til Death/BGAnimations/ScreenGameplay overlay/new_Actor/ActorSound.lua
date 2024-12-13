local returnFunction, level = ...;
if not returnFunction then
	return Def.Sound{
		Name = "New Sound",
		SupportPan = true,
		SupportRateChanging = true,
		IsAction = true,
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("Actor.lua", 1))(true, level+1);

local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);
end

local attrs = {
	SupportPan = nil,
	SupportRateChanging = nil,
	IsAction = nil,
	Precache = nil,
	File = Sound.load,
} .. baseAttrs;

return attrs, doPreProcess;
