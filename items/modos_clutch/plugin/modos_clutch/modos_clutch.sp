// SPDX-License-Identifier: GPL-3.0-or-later
// Clutch: winning a round adds a bot, losing one takes it away. Humans are on the side mp_humanteam says (CT).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Modes: clutch", author = "xsteban1410", version = "2.0" };

ConVar g_Clutch, g_ClutchMax;
int g_ClutchBots;

public void OnPluginStart()
{
	LoadTranslations("modos_clutch.phrases");
	g_Clutch    = CreateConVar("modo_clutch", "0", "Bots in the first round of the clutch mode (0 = off)");
	g_ClutchMax = CreateConVar("modo_clutch_max", "12", "Most bots the clutch mode can reach");
	HookEvent("round_prestart", OnPreStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", OnRoundEnd);
}

public void CSLS_OnModeReset()
{
	g_Clutch.RestoreDefault();
	g_ClutchMax.RestoreDefault();
}

public void OnMapStart()
{
	g_ClutchBots = 0;
}

public void OnPreStart(Event e, const char[] name, bool dontBroadcast)
{
	if (g_Clutch.IntValue <= 0 || GameRules_GetProp("m_bWarmupPeriod"))
		return;
	if (g_ClutchBots == 0)
		g_ClutchBots = g_Clutch.IntValue;
	ServerCommand("bot_quota %d", g_ClutchBots);
}

public void OnRoundEnd(Event e, const char[] name, bool dontBroadcast)
{
	if (g_Clutch.IntValue <= 0 || g_ClutchBots == 0 || GameRules_GetProp("m_bWarmupPeriod"))
		return;
	int winner = e.GetInt("winner");
	if (winner != CS_TEAM_T && winner != CS_TEAM_CT)
		return;
	g_ClutchBots += winner == CS_TEAM_CT ? 1 : -1;
	if (g_ClutchBots < 1)
		g_ClutchBots = 1;
	else if (g_ClutchBots > g_ClutchMax.IntValue)
		g_ClutchBots = g_ClutchMax.IntValue;
	PrintToChatAll(" \x04[Clutch]\x01 %t", "clutch_next", g_ClutchBots);
}
