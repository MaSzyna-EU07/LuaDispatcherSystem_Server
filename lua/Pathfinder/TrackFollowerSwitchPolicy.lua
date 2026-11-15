---@enum TrackFollowerSwitchPolicy
local TrackFollowerSwitchPolicy = {
	NORMAL = 0, -- The follower will continue going in the direction indicated by the current switch position.
	STOP = 1, -- The follower will stop if it encounters any switch.
	STOP_DIVERGING = 2, -- The follower will stop if it encounters a diverging switch. It will continue on if there's only one physically possible way of going further.
	RANDOM = 3 -- The follower will go in the direction of a randomly picked possible switch exit.
}
return TrackFollowerSwitchPolicy