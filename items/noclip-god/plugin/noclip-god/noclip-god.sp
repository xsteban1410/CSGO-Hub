// SPDX-License-Identifier: GPL-3.0-or-later
// !nc [target] noclip and !god [target] god mode, both toggles. Admins with the cheats permission (CUSTOM1).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>
#include <sdkhooks>

public Plugin myinfo = { name = "Noclip and god mode", author = "xsteban1410", description = "!nc and !god for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

bool g_God[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("noclip-god.phrases");
	RegAdminCmd("sm_nc", CmdNoclip, ADMFLAG_CUSTOM1, "sm_nc [target] - toggles noclip");
	RegAdminCmd("sm_god", CmdGod, ADMFLAG_CUSTOM1, "sm_god [target] - toggles god mode");
	HookEvent("player_spawn", OnSpawn);
}

public void OnClientDisconnect(int c)
{
	g_God[c] = false;
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

public Action CmdNoclip(int client, int args)
{
	int list[MAXPLAYERS];
	int n = Targets(client, args, list);
	for (int i = 0; i < n; i++)
	{
		int t = list[i];
		bool on = GetEntityMoveType(t) != MOVETYPE_NOCLIP;
		SetEntityMoveType(t, on ? MOVETYPE_NOCLIP : MOVETYPE_WALK);
		// flying is speed the anticheat would see
		if (on)
			CSLS_Exempt(t, 600.0);
		char who[MAX_NAME_LENGTH];
		GetClientName(t, who, sizeof(who));
		ShowActivity2(client, "[SM] ", "%t", on ? "on" : "off", "Noclip", who);
	}
	return Plugin_Handled;
}

public Action CmdGod(int client, int args)
{
	int list[MAXPLAYERS];
	int n = Targets(client, args, list);
	for (int i = 0; i < n; i++)
	{
		int t = list[i];
		g_God[t] = !g_God[t];
		SetEntProp(t, Prop_Data, "m_takedamage", g_God[t] ? 0 : 2, 1);
		char who[MAX_NAME_LENGTH];
		GetClientName(t, who, sizeof(who));
		ShowActivity2(client, "[SM] ", "%t", g_God[t] ? "on" : "off", "God", who);
	}
	return Plugin_Handled;
}

// god mode lasts until it is turned off, also after dying
public void OnSpawn(Event e, const char[] name, bool dontBroadcast)
{
	int c = GetClientOfUserId(e.GetInt("userid"));
	if (c > 0 && g_God[c])
		SetEntProp(c, Prop_Data, "m_takedamage", 0, 1);
}
