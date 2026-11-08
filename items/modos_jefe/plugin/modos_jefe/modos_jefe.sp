// SPDX-License-Identifier: GPL-3.0-or-later
// Boss: each round a random T bot turns giant, slow and with lots of health.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Modes: boss", author = "xsteban1410", version = "2.0" };

ConVar g_Jefe;

public void OnPluginStart()
{
	LoadTranslations("modos_jefe.phrases");
	g_Jefe = CreateConVar("modo_jefe", "0", "Health of the giant boss bot each round (0 = no boss)");
	HookEvent("round_freeze_end", OnFreezeEnd, EventHookMode_PostNoCopy);
}

public void CSLS_OnModeReset()
{
	g_Jefe.RestoreDefault();
}

public void OnFreezeEnd(Event e, const char[] name, bool dontBroadcast)
{
	if (g_Jefe.IntValue <= 0 || GameRules_GetProp("m_bWarmupPeriod"))
		return;
	int bots[MAXPLAYERS + 1], n = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T)
			bots[n++] = i;
	if (n == 0)
		return;
	int b = bots[GetRandomInt(0, n - 1)];
	SetEntityHealth(b, g_Jefe.IntValue);
	SetEntPropFloat(b, Prop_Send, "m_flModelScale", 1.6);
	SetEntPropFloat(b, Prop_Send, "m_flLaggedMovementValue", 0.85);
	SetEntityRenderMode(b, RENDER_TRANSCOLOR);
	SetEntityRenderColor(b, 255, 60, 60, 255);
	char bn[MAX_NAME_LENGTH];
	GetClientName(b, bn, sizeof(bn));
	PrintToChatAll(" \x04[Jefe]\x01 %t", "boss_is", bn, g_Jefe.IntValue);
}
