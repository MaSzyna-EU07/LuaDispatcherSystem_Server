---@enum Speed
Speed = {
    DIM = -1,
	STOP = 0,
	VMAX = 1,
	["40"] = 2,
	["60"] = 3,
	["100"] = 4,
	MS1 = 5,
	MS2 = 6,
	SZ = 7
}

---@enum SemaphoreType
SemaphoreType = {
	SEM = 0,
	TM = 1
}

---@enum PathMode
PathMode = {
	TRAIN = 0,
	SHUNT = 1
}

---@enum Severity
Severity = {
    INFO = "INFO",
    ERROR = "ERROR",
    SUCCESS = "SUCCESS",
    FAIL = "FAIL"
}

---@enum NotificationColor
NotificationColor = {
	GREEN = {0.15, 0.6, 0.05},
	RED = {0.9, 0.1, 0},
	GRAY = {0.4, 0.4, 0.4}
}

---@enum NotificationColorID
NotificationColorID = {
	[NotificationColor.GREEN] = 1,
	[NotificationColor.RED] = 2,
	[NotificationColor.GRAY] = 3
}