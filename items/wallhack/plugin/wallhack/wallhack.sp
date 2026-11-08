// SPDX-License-Identifier: GPL-3.0-or-later
// !wh [target]: a glowing copy of each enemy, sent only to whoever has it on. Admins with the cheats permission (CUSTOM1).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Admin wallhack", author = "xsteban1410", description = "!wh for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

#include <sdkhooks>

#define EF_BONEMERGE          (1 << 0)
#define EF_NOSHADOW           (1 << 4)
#define EF_NORECEIVESHADOW    (1 << 6)
#define EF_PARENT_ANIMATES    (1 << 9)

bool g_On[MAXPLAYERS + 1];
ArrayList g_Glows[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("wallhack.phrases");
	RegAdminCmd("sm_wh", CmdWh, ADMFLAG_CUSTOM1, "sm_wh [target] - toggles the wallhack");
	// players spawn and die all the time: rebuild the glows of whoever has it on
	HookEvent("player_spawn", Refresh, EventHookMode_PostNoCopy);
	HookEvent("player_death", Refresh, EventHookMode_PostNoCopy);
	HookEvent("player_team", Refresh, EventHookMode_PostNoCopy);
}

public void OnClientDisconnect(int c)
{
	g_On[c] = false;
	RemoveGlows(c);
	RequestFrame(RefreshAll);
}

public void OnMapEnd()
{
	for (int c = 1; c <= MaxClients; c++)
		delete g_Glows[c];
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

public Action CmdWh(int client, int args)
{
	int list[MAXPLAYERS];
	int n = Targets(client, args, list, false);
	for (int i = 0; i < n; i++)
	{
		int t = list[i];
		g_On[t] = !g_On[t];
		if (g_On[t])
			MakeGlows(t);
		else
			RemoveGlows(t);
		char who[MAX_NAME_LENGTH];
		GetClientName(t, who, sizeof(who));
		ShowActivity2(client, "[SM] ", "%t", g_On[t] ? "on" : "off", "Wallhack", who);
	}
	return Plugin_Handled;
}

public void Refresh(Event e, const char[] name, bool dontBroadcast)
{
	// after the spawn has set the model
	CreateTimer(0.3, RefreshTimer);
}

public Action RefreshTimer(Handle t)
{
	RefreshAll(0);
	return Plugin_Stop;
}

public void RefreshAll(any unused)
{
	for (int c = 1; c <= MaxClients; c++)
		if (g_On[c] && IsClientInGame(c))
			MakeGlows(c);
}

void MakeGlows(int c)
{
	RemoveGlows(c);
	g_Glows[c] = new ArrayList();
	ConVar ffa = FindConVar("mp_teammates_are_enemies");
	bool all = ffa != null && ffa.BoolValue;
	char model[PLATFORM_MAX_PATH];
	for (int e = 1; e <= MaxClients; e++)
	{
		if (e == c || !IsClientInGame(e) || !IsPlayerAlive(e) || !all && GetClientTeam(e) == GetClientTeam(c))
			continue;
		GetClientModel(e, model, sizeof(model));
		int g = CreateEntityByName("prop_dynamic_glow");
		if (g == -1)
			continue;
		DispatchKeyValue(g, "model", model);
		DispatchKeyValue(g, "solid", "0");
		DispatchKeyValue(g, "glowenabled", "1");
		DispatchKeyValue(g, "glowcolor", "255 40 40");
		DispatchKeyValue(g, "glowdist", "10000");
		DispatchKeyValue(g, "glowstyle", "0");
		DispatchSpawn(g);
		SetEntProp(g, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW | EF_PARENT_ANIMATES);
		SetVariantString("!activator");
		AcceptEntityInput(g, "SetParent", e, g);
		SetEntPropEnt(g, Prop_Send, "m_hOwnerEntity", c);
		SDKHook(g, SDKHook_SetTransmit, GlowTransmit);
		g_Glows[c].Push(EntIndexToEntRef(g));
	}
}

public Action GlowTransmit(int ent, int client)
{
	return GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client ? Plugin_Continue : Plugin_Handled;
}

void RemoveGlows(int c)
{
	if (g_Glows[c] == null)
		return;
	for (int i = 0; i < g_Glows[c].Length; i++)
	{
		int g = EntRefToEntIndex(g_Glows[c].Get(i));
		if (g > MaxClients)
			RemoveEntity(g);
	}
	delete g_Glows[c];
}
