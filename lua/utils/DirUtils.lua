---Functions for dealing with tile directions.
local DirUtils = {}

DirUtils.DIRS = {
	{x = 0, y = -1},
	{x = 1, y = -1},
	{x = 1, y = 0},
	{x = 1, y = 1},
	{x = 0, y = 1},
	{x = -1, y = 1},
	{x = -1, y = 0},
	{x = -1, y = -1}
}

---Inverts the provided direction, 1 becomes 5, 2 becomes 6, 7 becomes 3, and so on.
---@param dir integer The direction to invert.
---@return integer
function DirUtils.invertDir(dir)
	return (dir + 3) % 8 + 1
end

---Returns the angle of the provided direction, where 0 is to the right, and moving clockwise.
---@param dir integer The direction to calculate the angle from.
---@return number
function DirUtils.dirToAngle(dir)
	return (3 - dir) % 8 * math.pi / 4
end

---Returns the angles of the provided directions, similarly to `dirToAngle()`.
---@param dirs integer[] The directions to calculate the angles from.
---@return number[]
function DirUtils.dirsToAngles(dirs)
	local angles = {}
	for i, dir in ipairs(dirs) do
		table.insert(angles, DirUtils.dirToAngle(dir))
	end
	return angles
end

---Returns the closest direction to the specified angle in radians.
---@param angle number The angle to be considered.
---@return integer
function DirUtils.angleToDir(angle)
	return (2 - math.floor((angle + math.pi / 8) % (math.pi * 2) * 4 / math.pi)) % 8 + 1
end

---Turns a list of directions into their bitsum.
---@param dirs integer[] The list of directions.
---@return integer
function DirUtils.dirsToBitsum(dirs)
	local sum = 0
	for i, dir in ipairs(dirs) do
		sum = sum + 2 ^ (dir - 1)
	end
	return sum
end

return DirUtils