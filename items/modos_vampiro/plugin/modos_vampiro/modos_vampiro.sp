// SPDX-License-Identifier: GPL-3.0-or-later
// Vampire: part of the damage you deal heals you.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Modes: vampire", author = "xsteban1410", version = "2.0" };

ConVar g_Vampiro, g_VampiroMax;

public void OnPluginStart()
{
	g_Vampiro    = CreateConVar("modo_vampiro", "0", "Fraction of damage dealt that heals the attacker (0 = off)");
	g_VampiroMax = CreateConVar("modo_vampiro_max", "200", "Maximum health reachable by healing");
	HookEvent("player_hurt", OnHurt);
}

public void CSLS_OnModeReset()
{
	g_Vampiro.RestoreDefault();
	g_VampiroMax.RestoreDefault();
}

public void OnHurt(Event e, const char[] name, bool dontBroadcast)
{
	float f = g_Vampiro.FloatValue;
	if (f <= 0.0)
		return;
	int a = GetClientOfUserId(e.GetInt("attacker"));
	if (a < 1 || a == GetClientOfUserId(e.GetInt("userid")) || !IsPlayerAlive(a))
		return;
	int hp = GetClientHealth(a) + RoundToCeil(e.GetInt("dmg_health") * f);
	SetEntityHealth(a, hp < g_VampiroMax.IntValue ? hp : g_VampiroMax.IntValue);
}
