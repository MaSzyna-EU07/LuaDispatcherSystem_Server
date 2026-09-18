---@enum Speed
Speed = {
    DIM = -1,
	STOP = 0,
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
	DEBUG = "DEBUG",
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

---@enum TrackFollowerSwitchPolicy
TrackFollowerSwitchPolicy = {
	NORMAL = 0, -- The follower will continue going in the direction indicated by the current switch position.
	STOP = 1, -- The follower will stop if it encounters any switch.
	STOP_DIVERGING = 2, -- The follower will stop if it encounters a diverging switch. It will continue on if there's only one physically possible way of going further.
	RANDOM = 3 -- The follower will go in the direction of a randomly picked possible switch exit.
}