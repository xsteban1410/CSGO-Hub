// SPDX-License-Identifier: GPL-3.0-or-later
// !respawn [target] respawns dead players; !hp <target> <1-10000> sets health. Admins with the cheats permission (CUSTOM1).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Respawn and health", author = "xsteban1410", description = "!respawn and !hp for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("respawn-hp.phrases");
	RegAdminCmd("sm_respawn", CmdRespawn, ADMFLAG_CUSTOM1, "sm_respawn [target] - respawns players");
	RegAdminCmd("sm_hp", CmdHp, ADMFLAG_CUSTOM1, "sm_hp <target> <health> - sets health");
}

// Toggles `state` for each target of the command, or for whoever typed it when there is no target.
int Targets(int client, int args, int[] list, bool alive = true)
{
	if (args < 1)
	{
		if (client < 1)
		{
			ReplyToCommand(client, "[SM] Usage from the server: name a target");
			return 0;
		}
		list[0] = client;
		return 1;
	}
	char pattern[64], name[MAX_TARGET_LENGTH];
	bool ml;
	GetCmdArg(1, pattern, sizeof(pattern));
	int n = ProcessTargetString(pattern, client, list, MAXPLAYERS, alive ? COMMAND_FILTER_ALIVE : 0, name, sizeof(name), ml);
	if (n <= 0)
		ReplyToTargetError(client, n);
	return n;
}

public Action CmdRespawn(int client, int args)
{
	int list[MAXPLAYERS];
	int n = Targets(client, args, list, false);
	int done = 0;
	for (int i = 0; i < n; i++)
	{
		if (IsPlayerAlive(list[i]) || GetClientTeam(list[i]) < CS_TEAM_T)
			continue;
		CS_RespawnPlayer(list[i]);
		done++;
	}
	ShowActivity2(client, "[SM] ", "%t", "respawned", done);
	return Plugin_Handled;
}

public Action CmdHp(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] sm_hp <target> <1-10000>");
		return Plugin_Handled;
	}
	char arg[16];
	GetCmdArg(2, arg, sizeof(arg));
	int hp = StringToInt(arg);
	if (hp < 1 || hp > 10000)
	{
		ReplyToCommand(client, "[SM] sm_hp <target> <1-10000>");
		return Plugin_Handled;
	}
	int list[MAXPLAYERS];
	int n = Targets(client, args, list);
	for (int i = 0; i < n; i++)
		SetEntityHealth(list[i], hp);
	ShowActivity2(client, "[SM] ", "%t", "health_set", n, hp);
	return Plugin_Handled;
}
