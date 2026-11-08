// SPDX-License-Identifier: GPL-3.0-or-later
// Random: each round a weapon is drawn, the same for everyone.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Modes: random weapon", author = "xsteban1410", version = "2.0" };

ConVar g_Aleatorio, g_Quitar[2], g_Arma[2];

char g_Aleatorias[][] = {
	"weapon_awp", "weapon_ssg08", "weapon_ak47", "weapon_m4a1_silencer", "weapon_sg556", "weapon_aug",
	"weapon_famas", "weapon_galilar", "weapon_scar20", "weapon_nova", "weapon_xm1014", "weapon_mag7",
	"weapon_sawedoff", "weapon_negev", "weapon_m249", "weapon_p90", "weapon_mp9", "weapon_ump45",
	"weapon_bizon", "weapon_mp7", "weapon_deagle", "weapon_revolver", "weapon_fiveseven", "weapon_cz75a",
	"weapon_elite", "weapon_tec9", "weapon_p250", "weapon_taser"
};

public void OnPluginStart()
{
	LoadTranslations("modos_aleatorio.phrases");
	g_Aleatorio = CreateConVar("modo_aleatorio", "0", "1 = each round a weapon is drawn, the same for everyone");
	HookEvent("round_prestart", OnPreStart, EventHookMode_PostNoCopy);
}

// the engine's loadout convars exist once modos is loaded
public void OnAllPluginsLoaded()
{
	g_Quitar[0] = FindConVar("modo_t_quitar");
	g_Quitar[1] = FindConVar("modo_ct_quitar");
	g_Arma[0] = FindConVar("modo_t_arma");
	g_Arma[1] = FindConVar("modo_ct_arma");
}

public void CSLS_OnModeReset()
{
	g_Aleatorio.RestoreDefault();
}

// Drawn in round_prestart, before anyone spawns.
public void OnPreStart(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_Aleatorio.BoolValue || g_Arma[0] == null)
		return;
	char w[32];
	strcopy(w, sizeof(w), g_Aleatorias[GetRandomInt(0, sizeof(g_Aleatorias) - 1)]);
	for (int i = 0; i < 2; i++)
	{
		g_Arma[i].SetString(w);
		g_Quitar[i].SetInt(1);
	}
	PrintToChatAll(" \x04[Aleatorio]\x01 %t", "random_round", w[7]);
}
