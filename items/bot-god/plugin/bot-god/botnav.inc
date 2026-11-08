// SPDX-License-Identifier: GPL-3.0-or-later
// botnav: paths over the map's navigation mesh, for plugins. Needs the botnav item (and the app extracting "nav").
// A plugin that wants it optional includes this file, checks BotNav_Usable() and falls back when it is false.
// Keep every copy of this file identical (tools/lint.py checks it).
#if defined _botnav_included
 #endinput
#endif
#define _botnav_included

// True once the map's graph is loaded.
native bool BotNav_Ready();

// Centre of the nav area nearest to `pos`, written to `out`. False when there is no graph.
native bool BotNav_Nearest(const float pos[3], float out[3]);

// Walkable route from `from` to `to`: appends waypoints (float[3], block size 3) to `path` and returns how many; 0 = no route.
// The first is where to leave the start area, the last is `to`'s area centre.
native int BotNav_Path(const float from[3], const float to[3], ArrayList path);

// Name of the place (such as BombsiteA) at `pos`. False when the area has none.
native bool BotNav_PlaceAt(const float pos[3], char[] name, int len);

// Centre of the area nearest to the middle of the named place (case does not matter).
native bool BotNav_PlacePos(const char[] name, float out[3]);

// Hiding spots within `radius` of `pos`: appends float[3] to `out` (block size 3) and returns how many.
native int BotNav_Spots(const float pos[3], float radius, ArrayList out);

public SharedPlugin __pl_botnav =
{
	name = "botnav",
	file = "botnav.smx",
	required = 0,
};

public void __pl_botnav_SetNTVOptional()
{
	MarkNativeAsOptional("BotNav_Ready");
	MarkNativeAsOptional("BotNav_Nearest");
	MarkNativeAsOptional("BotNav_Path");
	MarkNativeAsOptional("BotNav_PlaceAt");
	MarkNativeAsOptional("BotNav_PlacePos");
	MarkNativeAsOptional("BotNav_Spots");
}

// Safe from any plugin: false when botnav is not installed or has no graph for this map.
stock bool BotNav_Usable()
{
	return GetFeatureStatus(FeatureType_Native, "BotNav_Ready") == FeatureStatus_Available && BotNav_Ready();
}
