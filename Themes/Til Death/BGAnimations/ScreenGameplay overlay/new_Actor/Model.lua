local returnFunction, level = ...;
if not returnFunction then
	return Def.Model{
		Name = "New Model",
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("Actor.lua", 1))(true, level+1);

local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);
end

local attrs = {
	Meshes = nil,
	Materials = nil,
	Bones = nil,
} .. baseAttrs;

return attrs, doPreProcess;
