// SPDX-License-Identifier: GPL-3.0-or-later
// !bots: a menu to add and kick bots, set their difficulty and freeze them. Admins with the bots permission (CUSTOM2).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>

public Plugin myinfo = { name = "Bots menu", author = "xsteban1410", description = "!bots for admins", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

public void OnPluginStart()
{
	LoadTranslations("bots-menu.phrases");
	RegAdminCmd("sm_bots", CmdBots, ADMFLAG_CUSTOM2, "sm_bots - menu to manage bots");
}

public Action CmdBots(int client, int args)
{
	if (client < 1)
	{
		ReplyToCommand(client, "[SM] In game only");
		return Plugin_Handled;
	}
	ShowBots(client);
	return Plugin_Handled;
}

void ShowBots(int client)
{
	Menu m = new Menu(OnBots);
	m.SetTitle("%T", "title", client);
	char text[64];
	// the menu's items run fixed commands: nothing typed by the player reaches the console
	static const char ids[][] = { "add_t", "add_ct", "kick_one", "kick_all", "diff_0", "diff_1", "diff_2", "diff_3", "freeze" };
	for (int i = 0; i < sizeof(ids); i++)
	{
		Format(text, sizeof(text), "%T", ids[i], client);
		m.AddItem(ids[i], text);
	}
	m.Display(client, MENU_TIME_FOREVER);
}

public int OnBots(Menu m, MenuAction a, int client, int item)
{
	if (a == MenuAction_End)
	{
		delete m;
		return 0;
	}
	if (a != MenuAction_Select)
		return 0;
	char id[16];
	m.GetItem(item, id, sizeof(id));
	ConVar quota = FindConVar("bot_quota");
	if (StrEqual(id, "add_t"))
		ServerCommand("bot_add_t");
	else if (StrEqual(id, "add_ct"))
		ServerCommand("bot_add_ct");
	else if (StrEqual(id, "kick_one") && quota != null && quota.IntValue > 0)
		quota.IntValue = quota.IntValue - 1;
	else if (StrEqual(id, "kick_all"))
		ServerCommand("bot_kick");
	else if (StrContains(id, "diff_") == 0)
		ServerCommand("bot_difficulty %d", StringToInt(id[5]));
	else if (StrEqual(id, "freeze"))
	{
		ConVar stop = FindConVar("bot_stop");
		if (stop != null)
			stop.BoolValue = !stop.BoolValue;
	}
	LogAction(client, -1, "\"%L\" used the bots menu: %s", client, id);
	ShowBots(client);
	return 0;
}
