// SPDX-License-Identifier: GPL-3.0-or-later
// !tp <target> goes to a player; !bring <target> brings players to where the admin is looking. Admins with the slay permission.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Teleport", author = "xsteban1410", description = "!tp and !bring for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("teleport.phrases");
	RegAdminCmd("sm_tp", CmdGoto, ADMFLAG_SLAY, "sm_tp <target> - goes to a player");
	RegAdminCmd("sm_bring", CmdBring, ADMFLAG_SLAY, "sm_bring <target> - brings players to where you look");
}

bool OneTarget(int client, int args, int &target)
{
	if (client < 1 || args < 1)
	{
		ReplyToCommand(client, "[SM] %t", "need_target");
		return false;
	}
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	target = FindTarget(client, arg, false, false);
	return target > 0 && IsPlayerAlive(target) && IsPlayerAlive(client);
}

public Action CmdGoto(int client, int args)
{
	int t;
	if (!OneTarget(client, args, t))
		return Plugin_Handled;
	float pos[3];
	GetClientAbsOrigin(t, pos);
	pos[2] += 80.0;  // on top, not inside them
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
	CSLS_Exempt(client, 3.0);
	ShowActivity2(client, "[SM] ", "%t", "went_to", t);
	return Plugin_Handled;
}

public bool NotPlayers(int ent, int mask) { return ent > MaxClients; }

public Action CmdBring(int client, int args)
{
	if (client < 1 || args < 1 || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] %t", "need_target");
		return Plugin_Handled;
	}
	float eye[3], ang[3], end[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, ang);
	TR_TraceRayFilter(eye, ang, MASK_PLAYERSOLID, RayType_Infinite, NotPlayers);
	TR_GetEndPosition(end);
	// a little back from the wall and above the floor
	float dir[3];
	GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, -40.0);
	AddVectors(end, dir, end);
	end[2] += 10.0;
	int list[MAXPLAYERS];
	char pattern[64], name[MAX_TARGET_LENGTH];
	bool ml;
	GetCmdArg(1, pattern, sizeof(pattern));
	int n = ProcessTargetString(pattern, client, list, MAXPLAYERS, COMMAND_FILTER_ALIVE, name, sizeof(name), ml);
	if (n <= 0)
	{
		ReplyToTargetError(client, n);
		return Plugin_Handled;
	}
	for (int i = 0; i < n; i++)
	{
		TeleportEntity(list[i], end, NULL_VECTOR, NULL_VECTOR);
		CSLS_Exempt(list[i], 3.0);
	}
	ShowActivity2(client, "[SM] ", "%t", "brought", name);
	return Plugin_Handled;
}
