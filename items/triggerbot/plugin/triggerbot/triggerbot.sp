// SPDX-License-Identifier: GPL-3.0-or-later
// !tb [target]: fires by itself when the crosshair is on an enemy. Admins with the cheats permission (CUSTOM1).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Admin triggerbot", author = "xsteban1410", description = "!tb for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

bool g_On[MAXPLAYERS + 1];
bool g_Held[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("triggerbot.phrases");
	RegAdminCmd("sm_tb", CmdTrig, ADMFLAG_CUSTOM1, "sm_tb [target] - toggles the triggerbot");
	CreateTimer(10.0, KeepExempt, _, TIMER_REPEAT);
}

public void OnClientDisconnect(int c)
{
	g_On[c] = false;
	g_Held[c] = false;
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

public Action CmdTrig(int client, int args)
{
	int list[MAXPLAYERS];
	int n = Targets(client, args, list, false);
	for (int i = 0; i < n; i++)
	{
		int t = list[i];
		g_On[t] = !g_On[t];
		if (g_On[t])
			CSLS_Exempt(t, 15.0);
		char who[MAX_NAME_LENGTH];
		GetClientName(t, who, sizeof(who));
		ShowActivity2(client, "[SM] ", "%t", g_On[t] ? "on" : "off", "Triggerbot", who);
	}
	return Plugin_Handled;
}

// the anticheat must not flag what this plugin does on purpose
public Action KeepExempt(Handle t)
{
	for (int c = 1; c <= MaxClients; c++)
		if (g_On[c] && IsClientInGame(c))
			CSLS_Exempt(c, 15.0);
	return Plugin_Continue;
}

public bool NotSelf(int ent, int mask, int self)
{
	return ent != self;
}

// Presses attack on the ticks the crosshair (recoil included) is on a living enemy. It lets go every other
// tick so pistols and snipers, which need a new press per shot, fire too.
public Action OnPlayerRunCmd(int c, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_On[c] || !IsPlayerAlive(c))
		return Plugin_Continue;
	if (g_Held[c])
	{
		g_Held[c] = false;
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	}
	int w = GetEntPropEnt(c, Prop_Send, "m_hActiveWeapon");
	if (w < 1)
		return Plugin_Continue;
	char cls[32];
	GetEntityClassname(w, cls, sizeof(cls));
	// grenades and C4 are not fired; the knife only reaches ~70 units
	if (StrContains(cls, "grenade") != -1 || StrContains(cls, "c4") != -1 || StrContains(cls, "decoy") != -1
		|| StrContains(cls, "flashbang") != -1 || StrContains(cls, "molotov") != -1 || StrContains(cls, "incgrenade") != -1)
		return Plugin_Continue;
	bool knife = StrContains(cls, "knife") != -1 || StrContains(cls, "bayonet") != -1;
	float ojo[3], punch[3], aim[3], dir[3], end[3];
	GetClientEyePosition(c, ojo);
	GetEntPropVector(c, Prop_Send, "m_aimPunchAngle", punch);
	aim[0] = angles[0] + punch[0] * 2.0;
	aim[1] = angles[1] + punch[1] * 2.0;
	aim[2] = 0.0;
	GetAngleVectors(aim, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, knife ? 70.0 : 8192.0);
	AddVectors(ojo, dir, end);
	TR_TraceRayFilter(ojo, end, MASK_SHOT, RayType_EndPoint, NotSelf, c);
	int e = TR_GetEntityIndex();
	if (e < 1 || e > MaxClients || !IsClientInGame(e) || !IsPlayerAlive(e))
		return Plugin_Continue;
	ConVar ffa = FindConVar("mp_teammates_are_enemies");
	if (GetClientTeam(e) == GetClientTeam(c) && !(ffa != null && ffa.BoolValue))
		return Plugin_Continue;
	buttons |= IN_ATTACK;
	g_Held[c] = true;
	return Plugin_Changed;
}
