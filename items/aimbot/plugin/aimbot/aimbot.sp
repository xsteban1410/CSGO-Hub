// SPDX-License-Identifier: GPL-3.0-or-later
// !am [target]: soft aimbot at the visible enemy head closest to the crosshair. Admins with the cheats permission (CUSTOM1).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Admin aimbot", author = "xsteban1410", description = "!am for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

bool g_On[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("aimbot.phrases");
	RegAdminCmd("sm_am", CmdAim, ADMFLAG_CUSTOM1, "sm_am [target] - toggles the aimbot");
	CreateTimer(10.0, KeepExempt, _, TIMER_REPEAT);
}

public void OnClientDisconnect(int c)
{
	g_On[c] = false;
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

public Action CmdAim(int client, int args)
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
		ShowActivity2(client, "[SM] ", "%t", g_On[t] ? "on" : "off", "Aimbot", who);
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

bool Visible(int c, int e, float cabeza[3])
{
	float ojo[3];
	GetClientEyePosition(c, ojo);
	GetClientEyePosition(e, cabeza);
	cabeza[2] -= 4.0;
	TR_TraceRayFilter(ojo, cabeza, MASK_SHOT, RayType_EndPoint, OnlyWorld, c);
	return !TR_DidHit() || TR_GetEntityIndex() == e;
}

public bool OnlyWorld(int ent, int mask, int self)
{
	return ent != self && (ent < 1 || ent > MaxClients);
}

float AngleDiff(float a, float b)
{
	float d = a - b;
	while (d > 180.0) d -= 360.0;
	while (d < -180.0) d += 360.0;
	return d;
}

// Eases the aim 35 % per tick toward the closest visible enemy head within 60 degrees of the crosshair.
public Action OnPlayerRunCmd(int c, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_On[c] || !IsPlayerAlive(c))
		return Plugin_Continue;
	float ojo[3], cabeza[3], best[3], dir[3], want[3];
	GetClientEyePosition(c, ojo);
	float bestDiff = 60.0;
	bool found = false;
	ConVar ffa = FindConVar("mp_teammates_are_enemies");
	bool all = ffa != null && ffa.BoolValue;
	for (int e = 1; e <= MaxClients; e++)
	{
		if (e == c || !IsClientInGame(e) || !IsPlayerAlive(e) || !all && GetClientTeam(e) == GetClientTeam(c))
			continue;
		if (!Visible(c, e, cabeza))
			continue;
		MakeVectorFromPoints(ojo, cabeza, dir);
		GetVectorAngles(dir, want);
		float diff = FloatAbs(AngleDiff(want[1], angles[1])) + FloatAbs(AngleDiff(want[0], angles[0]));
		if (diff < bestDiff)
		{
			bestDiff = diff;
			best = want;
			found = true;
		}
	}
	if (!found)
		return Plugin_Continue;
	angles[0] += AngleDiff(best[0], angles[0]) * 0.35;
	angles[1] += AngleDiff(best[1], angles[1]) * 0.35;
	if (!IsFakeClient(c))
		TeleportEntity(c, NULL_VECTOR, angles, NULL_VECTOR);
	return Plugin_Changed;
}
