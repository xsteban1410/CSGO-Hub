// SPDX-License-Identifier: GPL-3.0-or-later
// One bullet: one bullet in the pistol, each kill gives one more and any hit kills.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Modes: one bullet", author = "xsteban1410", version = "2.0" };

ConVar g_UnaBala;

public void OnPluginStart()
{
	g_UnaBala = CreateConVar("modo_unabala", "0", "1 = one bullet in the pistol, each kill gives +1 and any hit kills");
	HookEvent("player_death", OnDeath);
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void CSLS_OnModeReset()
{
	g_UnaBala.RestoreDefault();
}

public void OnClientPutInServer(int c)
{
	SDKHook(c, SDKHook_OnTakeDamage, OnTakeDamage);
}

// Leaves the pistol with 1 bullet and no reserve.
public void CSLS_OnEquip(int c)
{
	if (!g_UnaBala.BoolValue)
		return;
	int w = GetPlayerWeaponSlot(c, CS_SLOT_SECONDARY);
	if (w != -1)
	{
		SetEntProp(w, Prop_Send, "m_iClip1", 1);
		SetEntProp(w, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_UnaBala.BoolValue && attacker >= 1 && attacker <= MaxClients && attacker != victim)
	{
		damage = 1000.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnDeath(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_UnaBala.BoolValue)
		return;
	int a = GetClientOfUserId(e.GetInt("attacker"));
	if (a < 1 || a == GetClientOfUserId(e.GetInt("userid")) || !IsPlayerAlive(a))
		return;
	int w = GetPlayerWeaponSlot(a, CS_SLOT_SECONDARY);
	if (w != -1)
		SetEntProp(w, Prop_Send, "m_iClip1", GetEntProp(w, Prop_Send, "m_iClip1") + 1);
}
