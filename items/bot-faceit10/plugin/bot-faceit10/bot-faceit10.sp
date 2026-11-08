// SPDX-License-Identifier: GPL-3.0-or-later
// Bot skill level, active when the server runs with csls_bot_level == LEVEL (chosen in the app's bot difficulty).
// Only bots are touched. Aim, reaction, spray control, no friendly fire, and a utility evaluator that scores each
// grenade the bot holds against the situation (known enemies, allies, bomb, round time) and throws the best one,
// or none. The bots' own random grenade throwing is blocked.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csls>
#undef REQUIRE_PLUGIN
#include <botnav>
#define REQUIRE_PLUGIN

#if defined GOD
 #define LEVEL 5
 #define NAME "Bot level: God"
 #define REACT_MIN 0.04
 #define REACT_MAX 0.08
 #define EASE 0.65
 #define JITTER 0.0
 #define FIRE_ERR 0.8
 #define MIN_SCORE 28.0
 #define SCORE_NOISE 0.0
 #define SOLVE_TOL 40.0
 #define TARGET_NOISE 0.0
 #define ANG_NOISE 0.0
 #define ACQ_ERR 0.15
 #define ERR_DECAY 0.5
 #define POST_KILL_MIN 0.03
 #define POST_KILL_MAX 0.06
 #define STAGGER 0.0
 #define LEASH_MUL 0.6
 #define W_RUSH 5
 #define W_DEFAULT 25
 #define W_EXEC 70
#else
 #define LEVEL 4
 #define NAME "Bot level: Faceit Level 10"
 #define REACT_MIN 0.12
 #define REACT_MAX 0.18
 #define EASE 0.22
 #define JITTER 0.35
 #define FIRE_ERR 2.2
 #define MIN_SCORE 35.0
 #define SCORE_NOISE 15.0
 #define SOLVE_TOL 130.0
 #define TARGET_NOISE 110.0
 #define ANG_NOISE 1.4
 #define ACQ_ERR 3.5
 #define ERR_DECAY 0.86
 #define POST_KILL_MIN 0.12
 #define POST_KILL_MAX 0.30
 #define STAGGER 1.0
 #define LEASH_MUL 1.0
 #define W_RUSH 15
 #define W_DEFAULT 45
 #define W_EXEC 40
#endif

#define IDLE_TURN 3.0

public Plugin myinfo = { name = NAME, author = "xsteban1410", description = "Bot skill level", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

enum { N_NONE, N_FLASH, N_HE, N_SMOKE, N_MOLO, N_DECOY };

ConVar g_Level;
float g_RoundStart;
bool g_Planted;
float g_BombPos[3];
float g_TeamCool[4];

int g_Tgt[MAXPLAYERS + 1];
float g_Since[MAXPLAYERS + 1];
float g_React[MAXPLAYERS + 1];
int g_Burst[MAXPLAYERS + 1];
float g_NextEval[MAXPLAYERS + 1];
float g_NadeCool[MAXPLAYERS + 1];
float g_PrevYaw[MAXPLAYERS + 1];
float g_ErrP[MAXPLAYERS + 1];
float g_ErrY[MAXPLAYERS + 1];
float g_PauseUntil[MAXPLAYERS + 1];
float g_StrafeUntil[MAXPLAYERS + 1];
float g_StrafeDir[MAXPLAYERS + 1];
float g_StuckPos[MAXPLAYERS + 1][3];
float g_StuckAt[MAXPLAYERS + 1];
float g_UnstuckUntil[MAXPLAYERS + 1];
enum { TT_DEFAULT, TT_EXEC, TT_RUSH, CT_SETUP, CT_STACK, CT_AGGRO };
#define MAX_SITES 4
bool g_Tactical;                     // a bomb map in a classic game type: DM, arms race and the like have no tactics
int g_TargetSite;                    // the site the Ts go for
float g_Stage[3];                    // where an execute gathers before going in
bool g_HaveStage;
bool g_StageGo;                      // the Ts leave the staging point
int g_SiteCount;
float g_SitePos[MAX_SITES][3];
float g_SpawnPos[4][3];
bool g_HaveSpawn[4];
float g_Centroid[4][3];
bool g_HaveCentroid[4];
int g_Tactic[4];
int g_LostRow[4];
int g_StackSite;
int g_Role[MAXPLAYERS + 1];          // CT: site index to hold, -1 roams
float g_Release[MAXPLAYERS + 1];     // T: not before this time
bool g_Held[MAXPLAYERS + 1];
bool g_HoldSet[MAXPLAYERS + 1];
float g_HoldYaw[MAXPLAYERS + 1];
float g_AnchorPos[MAXPLAYERS + 1][3];
ConVar g_TuneDebug;
ConVar g_TuneTactics;
ConVar g_TuneLeash;
ConVar g_TuneReact;
ConVar g_TuneAim;
ConVar g_Rogues;
ConVar g_Chatter;

// what each team knows about the other: last time and place a member of the other team was seen
float g_KnownAt[4][MAXPLAYERS + 1];
float g_KnownPos[4][MAXPLAYERS + 1][3];

// throw plan per bot
int g_Phase[MAXPLAYERS + 1];        // 0 none, 1 equipping and aiming, 2 pin pulled, 3 released
int g_PlanType[MAXPLAYERS + 1];
float g_PlanAng[MAXPLAYERS + 1][2];
float g_PlanLand[MAXPLAYERS + 1][3];
float g_PlanAt[MAXPLAYERS + 1];
bool g_PlanJump[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_Level = CreateConVar("csls_bot_level", "0", "Bot skill: 4 = Faceit Level 10, 5 = God. Set by the app from the difficulty chosen.", _, true, 0.0, true, 5.0);
	HookEvent("round_start", EvRoundStart);
	HookEvent("round_freeze_end", EvFreezeEnd);
	HookEvent("bomb_planted", EvPlanted);
	HookEvent("player_death", EvDeath);
	g_TuneDebug = CreateConVar("bot_tune_debug", "0", "Log the bot levels' decisions (tactics, routes) to the server log.", _, true, 0.0, true, 1.0);
	g_TuneTactics = CreateConVar("bot_tune_tactics", "1", "Team tactics for the bot levels: roles, tempo, holds.", _, true, 0.0, true, 1.0);
	g_TuneLeash = CreateConVar("bot_tune_leash", "700", "Units a bot may get ahead of its team while a tactic keeps them together.", _, true, 100.0, true, 3000.0);
	g_TuneReact = CreateConVar("bot_tune_react", "1.0", "Multiplier on the reaction time of the bot levels.", _, true, 0.2, true, 4.0);
	g_TuneAim = CreateConVar("bot_tune_aim_error", "1.0", "Multiplier on the first-flick error of the bot levels.", _, true, 0.0, true, 4.0);
	HookEvent("round_end", EvRoundEnd);
	g_Rogues = FindConVar("bot_allow_rogues");
	g_Chatter = FindConVar("bot_chatter");
	HookEvent("bomb_defused", EvBombEnd);
	HookEvent("bomb_exploded", EvBombEnd);
	CreateTimer(0.25, TimerScan, _, TIMER_REPEAT);
}

#if defined GOD
// Exact lineups from configs/botgod_lineups.cfg: used when a bot stands on one with that grenade.
#define MAX_LU 128
int g_LuCount;
int g_LuType[MAX_LU];
int g_LuTeam[MAX_LU];
bool g_LuJump[MAX_LU];
float g_LuPos[MAX_LU][3];
float g_LuAng[MAX_LU][2];

void LoadLineups()
{
	g_LuCount = 0;
	char path[PLATFORM_MAX_PATH], map[64], v[64], parts[3][16];
	BuildPath(Path_SM, path, sizeof(path), "configs/botgod_lineups.cfg");
	GetCurrentMap(map, sizeof(map));
	KeyValues kv = new KeyValues("Lineups");
	if (kv.ImportFromFile(path) && kv.JumpToKey(map) && kv.GotoFirstSubKey())
	{
		do
		{
			if (g_LuCount >= MAX_LU)
				break;
			kv.GetString("type", v, sizeof(v));
			int type = StrEqual(v, "flash") ? N_FLASH : StrEqual(v, "he") ? N_HE : StrEqual(v, "smoke") ? N_SMOKE : StrEqual(v, "molotov") ? N_MOLO : N_NONE;
			kv.GetString("team", v, sizeof(v));
			int team = StrEqual(v, "t") ? CS_TEAM_T : StrEqual(v, "ct") ? CS_TEAM_CT : StrEqual(v, "any") ? 1 : 0;
			if (type == N_NONE || team == 0)
				continue;
			kv.GetString("pos", v, sizeof(v));
			if (ExplodeString(v, " ", parts, 3, 16) != 3)
				continue;
			for (int i = 0; i < 3; i++)
				g_LuPos[g_LuCount][i] = StringToFloat(parts[i]);
			kv.GetString("ang", v, sizeof(v));
			if (ExplodeString(v, " ", parts, 2, 16) != 2)
				continue;
			g_LuAng[g_LuCount][0] = StringToFloat(parts[0]);
			g_LuAng[g_LuCount][1] = StringToFloat(parts[1]);
			g_LuType[g_LuCount] = type;
			g_LuJump[g_LuCount] = kv.GetNum("jump", 0) != 0;
			g_LuTeam[g_LuCount] = team;
			g_LuCount++;
		}
		while (kv.GotoNextKey());
	}
	delete kv;
}

// A lineup under the bot's feet for a grenade it holds: throw it as recorded.
bool TryLineup(int c)
{
	float me[3];
	GetClientAbsOrigin(c, me);
	for (int i = 0; i < g_LuCount; i++)
	{
		// the sources may record feet or eyes: compare on the floor plan and allow a height gap
		float dx = me[0] - g_LuPos[i][0], dy = me[1] - g_LuPos[i][1], dz = FloatAbs(me[2] - g_LuPos[i][2]);
		if ((g_LuTeam[i] != 1 && g_LuTeam[i] != GetClientTeam(c)) || FindNade(c, g_LuType[i]) < 1 || SquareRoot(dx * dx + dy * dy) > 40.0 || dz > 80.0)
			continue;
		g_Phase[c] = 1;
		g_PlanType[c] = g_LuType[i];
		g_PlanAng[c] = g_LuAng[i];
		g_PlanLand[c] = g_LuPos[i];
		g_PlanJump[c] = g_LuJump[i];
		g_PlanAt[c] = GetGameTime();
		g_TeamCool[GetClientTeam(c)] = g_PlanAt[c] + 1.5;
		return true;
	}
	return false;
}
#endif

public void CSLS_OnModeReset()
{
	g_Level.RestoreDefault();
	g_TuneDebug.RestoreDefault();
	g_TuneTactics.RestoreDefault();
	g_TuneLeash.RestoreDefault();
	g_TuneReact.RestoreDefault();
	g_TuneAim.RestoreDefault();
	if (g_Rogues != null) g_Rogues.RestoreDefault();
	if (g_Chatter != null) g_Chatter.RestoreDefault();
}

bool Active()
{
	return g_Level.IntValue == LEVEL;
}

public void EvRoundStart(Event e, const char[] n, bool b)
{
	// no lone wolves wandering off, no radio spam
	if (Active())
	{
		if (g_Rogues != null) g_Rogues.IntValue = 0;
		if (g_Chatter != null) g_Chatter.SetString("minimal");
	}
	g_Planted = false;
	g_RoundStart = 0.0;
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		g_Phase[i] = 0;
		g_Tgt[i] = 0;
		g_KnownAt[2][i] = g_KnownAt[3][i] = 0.0;
	}
	g_TeamCool[2] = g_TeamCool[3] = 0.0;
	if (Active())
		CreateTimer(0.5, TimerPick);
}

// A teammate falls: the team now knows where the killer is and the bots nearby swing to it (trade). The killer
// takes a beat before choosing the next target, like a person would.
public void EvDeath(Event e, const char[] n, bool b)
{
	if (!Active())
		return;
	int victim = GetClientOfUserId(e.GetInt("userid")), killer = GetClientOfUserId(e.GetInt("attacker"));
	if (!Alive(killer) || killer == victim || victim < 1)
		return;
	int vt = GetClientTeam(victim);
	if (GetClientTeam(killer) != vt)
	{
		float pos[3];
		GetClientAbsOrigin(killer, pos);
		pos[2] += 40.0;
		g_KnownAt[vt][killer] = GetGameTime();
		g_KnownPos[vt][killer] = pos;
	}
	g_PauseUntil[killer] = GetGameTime() + GetRandomFloat(POST_KILL_MIN, POST_KILL_MAX);
}

public void EvFreezeEnd(Event e, const char[] n, bool b)
{
	g_RoundStart = GetGameTime();
}

public void EvPlanted(Event e, const char[] n, bool b)
{
	g_Planted = true;
	int c4 = FindEntityByClassname(-1, "planted_c4");
	if (c4 != -1)
		GetEntPropVector(c4, Prop_Send, "m_vecOrigin", g_BombPos);
}

public void EvBombEnd(Event e, const char[] n, bool b)
{
	g_Planted = false;
}

public void OnClientDisconnect(int c)
{
	PathClear(c);
	g_Phase[c] = 0;
	g_Tgt[c] = 0;
}

// ---------------------------------------------------------------- helpers

bool IsBot(int c)
{
	return c >= 1 && c <= MaxClients && IsClientInGame(c) && IsFakeClient(c) && IsPlayerAlive(c);
}

bool Alive(int c)
{
	return c >= 1 && c <= MaxClients && IsClientInGame(c) && IsPlayerAlive(c);
}

public bool OnlyWorld(int ent, int mask, any self)
{
	return ent > MaxClients;
}

public bool NotSelf(int ent, int mask, any self)
{
	return ent != self;
}

bool Clear(const float a[3], const float b[3])
{
	TR_TraceRayFilter(a, b, MASK_SOLID, RayType_EndPoint, OnlyWorld, 0);
	return !TR_DidHit();
}

float AngleDiff(float a, float b)
{
	float d = a - b;
	while (d > 180.0) d -= 360.0;
	while (d < -180.0) d += 360.0;
	return d;
}

int NadeType(const char[] cls)
{
	if (StrEqual(cls, "weapon_flashbang")) return N_FLASH;
	if (StrEqual(cls, "weapon_hegrenade")) return N_HE;
	if (StrEqual(cls, "weapon_smokegrenade")) return N_SMOKE;
	if (StrEqual(cls, "weapon_molotov") || StrEqual(cls, "weapon_incgrenade")) return N_MOLO;
	if (StrEqual(cls, "weapon_decoy")) return N_DECOY;
	return N_NONE;
}

int ActiveWeapon(int c)
{
	return GetEntPropEnt(c, Prop_Send, "m_hActiveWeapon");
}

int ActiveNade(int c)
{
	int w = ActiveWeapon(c);
	if (w < 1)
		return N_NONE;
	char cls[32];
	GetEntityClassname(w, cls, sizeof(cls));
	return NadeType(cls);
}

// The grenade entity of `type` in the bot's inventory, or -1.
int FindNade(int c, int type)
{
	for (int i = 0; i < 64; i++)
	{
		int w = GetEntPropEnt(c, Prop_Send, "m_hMyWeapons", i);
		if (w < 1)
			continue;
		char cls[32];
		GetEntityClassname(w, cls, sizeof(cls));
		if (NadeType(cls) == type)
			return w;
	}
	return -1;
}

int Gun(int c)
{
	int w = GetPlayerWeaponSlot(c, 0);
	if (w < 1)
		w = GetPlayerWeaponSlot(c, 1);
	if (w < 1)
		w = GetPlayerWeaponSlot(c, 2);
	return w;
}

bool IsGun(int w)
{
	if (w < 1)
		return false;
	char cls[32];
	GetEntityClassname(w, cls, sizeof(cls));
	return NadeType(cls) == N_NONE && StrContains(cls, "knife") == -1 && StrContains(cls, "bayonet") == -1 && !StrEqual(cls, "weapon_c4") && !StrEqual(cls, "weapon_taser");
}

bool IsSniper(int w)
{
	char cls[32];
	GetEntityClassname(w, cls, sizeof(cls));
	return StrEqual(cls, "weapon_awp") || StrEqual(cls, "weapon_ssg08") || StrEqual(cls, "weapon_scar20") || StrEqual(cls, "weapon_g3sg1");
}

bool HasAwp(int c)
{
	int w = GetPlayerWeaponSlot(c, 0);
	if (w < 1)
		return false;
	char cls[32];
	GetEntityClassname(w, cls, sizeof(cls));
	return StrEqual(cls, "weapon_awp");
}

float Dist(const float a[3], const float b[3])
{
	return GetVectorDistance(a, b);
}

// distance from point p to the segment a-b
float SegDist(const float p[3], const float a[3], const float b[3])
{
	float ab[3], ap[3], q[3];
	SubtractVectors(b, a, ab);
	SubtractVectors(p, a, ap);
	float len2 = GetVectorDotProduct(ab, ab);
	float t = len2 > 0.0 ? GetVectorDotProduct(ap, ab) / len2 : 0.0;
	if (t < 0.0) t = 0.0;
	if (t > 1.0) t = 1.0;
	q[0] = a[0] + ab[0] * t; q[1] = a[1] + ab[1] * t; q[2] = a[2] + ab[2] * t;
	return Dist(p, q);
}

// ---------------------------------------------------------------- what each team knows

// Every 0.25 s: enemies seen by at least one living member of the other team are "known" for a while.
public Action TimerScan(Handle t)
{
	if (!Active())
		return Plugin_Continue;
	float now = GetGameTime();
	for (int team = 2; team <= 3; team++)
	{
		float sum[3];
		int n = 0;
		sum[0] = sum[1] = sum[2] = 0.0;
		for (int m = 1; m <= MaxClients; m++)
			if (Alive(m) && GetClientTeam(m) == team)
			{
				float o[3];
				GetClientAbsOrigin(m, o);
				AddVectors(sum, o, sum);
				n++;
			}
		g_HaveCentroid[team] = n >= 3;
		if (n)
			ScaleVector(sum, 1.0 / n);
		g_Centroid[team] = sum;
	}
	// the execute leaves its staging point when the Ts are there, or after a while
	if (g_Tactical && g_Tactic[CS_TEAM_T] == TT_EXEC && !g_StageGo && g_RoundStart > 0.0)
	{
		bool all = true;
		for (int m = 1; m <= MaxClients; m++)
			if (IsBot(m) && GetClientTeam(m) == CS_TEAM_T)
			{
				float o[3];
				GetClientAbsOrigin(m, o);
				if (Dist(o, g_Stage) > 600.0)
					all = false;
			}
		if (all || !g_HaveStage || now - g_RoundStart > 25.0)
		{
			g_StageGo = true;
			if (g_TuneDebug.BoolValue)
				LogMessage("bot level %d: the execute goes in (%s)", LEVEL, all ? "all gathered" : "time");
		}
	}
	for (int team = 2; team <= 3; team++)
	{
		for (int e = 1; e <= MaxClients; e++)
		{
			if (!Alive(e) || GetClientTeam(e) == team || GetClientTeam(e) < 2)
				continue;
			float ep[3];
			GetClientAbsOrigin(e, ep);
			ep[2] += 40.0;
			for (int m = 1; m <= MaxClients; m++)
			{
				if (!Alive(m) || GetClientTeam(m) != team)
					continue;
				float eye[3];
				GetClientEyePosition(m, eye);
				if (Dist(eye, ep) < 3000.0 && Clear(eye, ep))
				{
					g_KnownAt[team][e] = now;
					g_KnownPos[team][e] = ep;
					break;
				}
			}
		}
	}
	return Plugin_Continue;
}

bool Known(int team, int e)
{
	return GetGameTime() - g_KnownAt[team][e] < 2.0;
}

// ---------------------------------------------------------------- throw physics

// Where a grenade of `type` thrown at full strength ends up: the first floor hit for fire, the resting place
// after the fuse for the others. Walls bounce it. shortcut: Source's grenade physics are approximated
// (elasticity .45, friction .2); the result is within tens of units, which is what the God level aims at.
void NadeLanding(int c, int type, float pitch, float yaw, float out[3])
{
	float eye[3], ang[3], fwd[3], vel[3], pos[3], cv[3], nxt[3], n[3];
	GetClientEyePosition(c, eye);
	float tp = pitch - 10.0 + FloatAbs(pitch) * (10.0 / 90.0);
	ang[0] = tp; ang[1] = yaw; ang[2] = 0.0;
	GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);
	float speed = (90.0 - tp) * 6.0;
	if (speed > 750.0) speed = 750.0;
	if (speed < 15.0) speed = 15.0;
	GetEntPropVector(c, Prop_Data, "m_vecVelocity", cv);
	for (int i = 0; i < 3; i++)
	{
		vel[i] = fwd[i] * speed + cv[i] * 1.25;
		pos[i] = eye[i] + fwd[i] * 16.0;
	}
	float g = FindConVar("sv_gravity").FloatValue * 0.4;
	float maxT = type == N_SMOKE ? 2.6 : (type == N_MOLO ? 2.0 : 1.6);
	float dt = 0.03125;
	float mins[3] = { -2.0, -2.0, -2.0 }, maxs[3] = { 2.0, 2.0, 2.0 };
	for (float t = 0.0; t < maxT; t += dt)
	{
		nxt[0] = pos[0] + vel[0] * dt; nxt[1] = pos[1] + vel[1] * dt; nxt[2] = pos[2] + vel[2] * dt;
		vel[2] -= g * dt;
		TR_TraceHullFilter(pos, nxt, mins, maxs, MASK_SOLID, OnlyWorld, 0);
		if (TR_DidHit())
		{
			TR_GetEndPosition(pos);
			TR_GetPlaneNormal(null, n);
			if (type == N_MOLO && n[2] > 0.7)
				break;
			float back = GetVectorDotProduct(vel, n) * 1.45;
			for (int i = 0; i < 3; i++)
				vel[i] -= n[i] * back;
			vel[0] *= 0.8; vel[1] *= 0.8;
			if (n[2] > 0.7 && GetVectorLength(vel) < 40.0)
				break;
		}
		else
			pos = nxt;
	}
	out = pos;
}

// Finds the throw angles that land on `tgt`. False when no pitch gets within the level's tolerance.
bool SolveThrow(int c, int type, const float tgt[3], float outAng[2], float land[3])
{
	float eye[3], d[3], a[3], p[3];
	GetClientEyePosition(c, eye);
	SubtractVectors(tgt, eye, d);
	GetVectorAngles(d, a);
	float yaw = a[1];
	float best = 99999.0, bestP = 0.0;
	for (float pitch = -85.0; pitch <= 8.0; pitch += 1.5)
	{
		NadeLanding(c, type, pitch, yaw, p);
		float dd = Dist(p, tgt);
		if (dd < best) { best = dd; bestP = pitch; land = p; }
	}
#if defined GOD
	float lo = bestP - 1.5;
	for (float pitch = lo; pitch <= bestP + 1.5; pitch += 0.1)
	{
		NadeLanding(c, type, pitch, yaw, p);
		float dd = Dist(p, tgt);
		if (dd < best) { best = dd; bestP = pitch; land = p; }
	}
#endif
	if (best > SOLVE_TOL)
		return false;
	outAng[0] = bestP + GetRandomFloat(-ANG_NOISE, ANG_NOISE);
	outAng[1] = yaw + GetRandomFloat(-ANG_NOISE, ANG_NOISE);
	return true;
}

// ---------------------------------------------------------------- utility evaluator

// How good is it to throw `type` at known enemy `e` now? Below zero = never. `tgt` is where it should land.
float Score(int c, int type, int e, float tgt[3])
{
	int team = GetClientTeam(c);
	float ep[3], me[3], eye[3];
	ep = g_KnownPos[team][e];
	GetClientAbsOrigin(c, me);
	GetClientEyePosition(c, eye);
	float dist = Dist(me, ep);
	float elapsed = g_RoundStart > 0.0 ? GetGameTime() - g_RoundStart : 0.0;
	tgt = ep;
	tgt[2] -= 38.0;

	// how many enemies stand together, and whether one holds still
	int cluster = 0;
	bool still = false;
	int hp = 100;
	for (int o = 1; o <= MaxClients; o++)
	{
		if (!Alive(o) || GetClientTeam(o) == team || !Known(team, o))
			continue;
		if (Dist(g_KnownPos[team][o], ep) < 350.0)
		{
			cluster++;
			float v[3];
			GetEntPropVector(o, Prop_Data, "m_vecVelocity", v);
			if (o == e)
			{
				still = GetVectorLength(v) < 40.0;
				hp = GetClientHealth(o);
			}
		}
	}

	float s = -1.0;
	if (type == N_HE)
	{
		if (dist < 350.0 || dist > 1300.0) return -1.0;
		s = 25.0 + 30.0 * (cluster - 1) + (hp <= 60 ? 15.0 : 0.0);
	}
	else if (type == N_MOLO)
	{
		if (dist < 400.0 || dist > 1400.0) return -1.0;
		s = 30.0 + (still ? 25.0 : 0.0);
		if (g_Planted && team == CS_TEAM_T && Dist(ep, g_BombPos) < 350.0)
		{
			s += 45.0;                       // deny the defuse
			tgt = g_BombPos;
		}
	}
	else if (type == N_FLASH)
	{
		if (dist < 300.0 || dist > 1500.0) return -1.0;
		s = 40.0;
		for (int a = 1; a <= MaxClients; a++)
			if (a != c && Alive(a) && GetClientTeam(a) == team && GetClientTeam(a) >= 2)
			{
				float ap[3];
				GetClientAbsOrigin(a, ap);
				if (Dist(ap, me) < 700.0)
					s += 10.0;               // a teammate to follow up
				if (Dist(ap, tgt) < 900.0 && Clear(ap, tgt))
					return -1.0;             // it would blind them
			}
		tgt[2] += 90.0;                       // pops in front of the face
	}
	else if (type == N_SMOKE)
	{
		if (dist < 800.0) return -1.0;
		if (elapsed < 12.0 && !HasAwp(e)) return -1.0;
		s = 25.0 + (HasAwp(e) ? 25.0 : 0.0);
		if (g_Planted && team == CS_TEAM_CT)
		{
			s += 20.0;                       // cover the defuse
			tgt = g_BombPos;
		}
		else
		{
			float d[3];
			SubtractVectors(eye, ep, d);
			NormalizeVector(d, d);
			tgt[0] = ep[0] + d[0] * 220.0; tgt[1] = ep[1] + d[1] * 220.0; tgt[2] = ep[2] - 38.0;
		}
	}
	else
		return -1.0;

	// never next to teammates or on yourself
	if (type == N_HE || type == N_MOLO)
		if (Dist(me, tgt) < 350.0)
			return -1.0;
	for (int a = 1; a <= MaxClients; a++)
	{
		if (a == c || !Alive(a) || GetClientTeam(a) != team)
			continue;
		float ap[3];
		GetClientAbsOrigin(a, ap);
		float r = (type == N_HE || type == N_MOLO) ? 380.0 : 150.0;
		if (Dist(ap, tgt) < r)
			return -1.0;
		if (SegDist(ap, eye, tgt) < 90.0)    // a teammate in the way
			return -1.0;
	}
	if (team == CS_TEAM_T && g_Tactic[team] == TT_EXEC)
		s += 12.0;                               // the execute is about utility
	return s + GetRandomFloat(-SCORE_NOISE, SCORE_NOISE);
}

// Picks the best (grenade, enemy) pair for bot `c` and starts a plan, or does nothing.
void Evaluate(int c)
{
	float now = GetGameTime();
	if (g_RoundStart <= 0.0 || now - g_RoundStart < 6.0 || now < g_NadeCool[c] || now < g_TeamCool[GetClientTeam(c)])
		return;
	int team = GetClientTeam(c);
#if defined GOD
	if (TryLineup(c))
		return;
#endif
	float best = MIN_SCORE, tgt[3], bt[3];
	int bestType = N_NONE;
	for (int type = N_FLASH; type <= N_MOLO; type++)
	{
		if (FindNade(c, type) < 1)
			continue;
		for (int e = 1; e <= MaxClients; e++)
		{
			if (!Alive(e) || GetClientTeam(e) == team || GetClientTeam(e) < 2 || !Known(team, e))
				continue;
			float s = Score(c, type, e, tgt);
			if (s > best)
			{
				best = s;
				bestType = type;
				bt = tgt;
			}
		}
	}
	if (bestType == N_NONE)
		return;
	// the human-level bot miscalculates; the God level aims exactly
	if (TARGET_NOISE > 0.0)
	{
		bt[0] += GetRandomFloat(-TARGET_NOISE, TARGET_NOISE);
		bt[1] += GetRandomFloat(-TARGET_NOISE, TARGET_NOISE);
	}
	float ang[2], land[3];
	if (!SolveThrow(c, bestType, bt, ang, land))
		return;
	g_Phase[c] = 1;
	g_PlanType[c] = bestType;
	g_PlanAng[c] = ang;
	g_PlanLand[c] = land;
	g_PlanJump[c] = false;
	g_PlanAt[c] = now;
	g_TeamCool[team] = now + 1.5;
}

// Runs the plan: take out the grenade, face the aim, pull the pin, release, put the gun back.
// Returns true when the plan owns this tick.
bool RunPlan(int c, int &buttons, float vel[3], float angles[3], int &weapon)
{
	float now = GetGameTime();
	if (g_Phase[c] == 0)
		return false;
	int nade = FindNade(c, g_PlanType[c]);
	if (nade < 1 || now - g_PlanAt[c] > 5.0 || !GetEntProp(c, Prop_Send, "m_iHealth"))
	{
		g_Phase[c] = 0;
		g_NadeCool[c] = now + 3.0;
		return false;
	}
	vel[0] = vel[1] = 0.0;
	buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK | IN_ATTACK2 | IN_JUMP);
	if (g_Phase[c] == 1)
	{
		weapon = nade;
		angles[0] += AngleDiff(g_PlanAng[c][0], angles[0]) * (EASE + 0.1);
		angles[1] += AngleDiff(g_PlanAng[c][1], angles[1]) * (EASE + 0.1);
		float err = FloatAbs(AngleDiff(g_PlanAng[c][0], angles[0])) + FloatAbs(AngleDiff(g_PlanAng[c][1], angles[1]));
		if (ActiveWeapon(c) == nade && err < 0.8)
		{
			g_Phase[c] = 2;
			g_PlanAt[c] = now;
		}
	}
	else if (g_Phase[c] == 2)
	{
		angles[0] = g_PlanAng[c][0];
		angles[1] = g_PlanAng[c][1];
		buttons |= IN_ATTACK;
		if (now - g_PlanAt[c] > 0.25)
		{
			g_Phase[c] = 3;
			g_PlanAt[c] = now;
			if (g_PlanJump[c])
				buttons = (buttons & ~IN_ATTACK) | IN_JUMP;   // jump throw: the grenade leaves as the jump starts
		}
	}
	else
	{
		angles[0] = g_PlanAng[c][0];
		angles[1] = g_PlanAng[c][1];
		if (g_PlanJump[c] && now - g_PlanAt[c] < 0.1)
			buttons |= IN_JUMP;
		if (now - g_PlanAt[c] > 0.4)
		{
			weapon = Gun(c);
			g_Phase[c] = 0;
			g_NadeCool[c] = now + 5.0;
		}
	}
	return true;
}

// ---------------------------------------------------------------- walking routes (needs the botnav item)
// A bot that a tactic sends somewhere follows a route over the nav mesh by steering its own movement; as soon as an
// enemy is in sight, or the route ends, the game's own movement takes over again.

ArrayList g_Path[MAXPLAYERS + 1];
int g_PathIdx[MAXPLAYERS + 1];
float g_PathGoal[MAXPLAYERS + 1][3];
float g_PathAt[MAXPLAYERS + 1];
float g_ProgAt[MAXPLAYERS + 1];
float g_ProgPos[MAXPLAYERS + 1][3];

bool NavOk()
{
	return BotNav_Usable();
}

void PathClear(int c)
{
	delete g_Path[c];
	g_PathIdx[c] = 0;
}

// Plans a route to `goal` unless the one in use already goes there. False when there is none.
bool PathTo(int c, const float goal[3])
{
	float now = GetGameTime();
	if (g_Path[c] != null && g_Path[c].Length > g_PathIdx[c] && Dist(g_PathGoal[c], goal) < 150.0 && now - g_PathAt[c] < 8.0)
		return true;
	float org[3];
	GetClientAbsOrigin(c, org);
	PathClear(c);
	ArrayList p = new ArrayList(3);
	if (BotNav_Path(org, goal, p) < 1)
	{
		delete p;
		return false;
	}
	g_Path[c] = p;
	g_PathGoal[c] = goal;
	g_PathAt[c] = now;
	g_ProgAt[c] = now;
	g_ProgPos[c] = org;
	return true;
}

// One step along the route: sets the movement and the look direction. False when there is no route or it ended.
bool PathStep(int c, int &buttons, float vel[3], float angles[3])
{
	if (g_Path[c] == null)
		return false;
	float org[3], wp[3], now = GetGameTime();
	GetClientAbsOrigin(c, org);
	while (g_PathIdx[c] < g_Path[c].Length)
	{
		g_Path[c].GetArray(g_PathIdx[c], wp, 3);
		float ddx = wp[0] - org[0], ddy = wp[1] - org[1];
		// reached: close on the floor plan, and not far above us (a drop below counts: we step off and fall)
		if (SquareRoot(ddx * ddx + ddy * ddy) < 40.0 && wp[2] - org[2] < 90.0)
			g_PathIdx[c]++;
		else
			break;
	}
	if (g_PathIdx[c] >= g_Path[c].Length)
	{
		PathClear(c);
		return false;
	}
	float dx = wp[0] - org[0], dy = wp[1] - org[1];
	float len = SquareRoot(dx * dx + dy * dy);
	if (len < 1.0)
		len = 1.0;
	float rad = angles[1] * 0.0174533;
	float fx = Cosine(rad), fy = Sine(rad), wx = dx / len, wy = dy / len;
	vel[0] = (wx * fx + wy * fy) * 450.0;
	vel[1] = (wx * fy - wy * fx) * 450.0;
	buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
	if (vel[0] > 10.0) buttons |= IN_FORWARD;
	else if (vel[0] < -10.0) buttons |= IN_BACK;
	if (vel[1] > 10.0) buttons |= IN_MOVERIGHT;
	else if (vel[1] < -10.0) buttons |= IN_MOVELEFT;
	// steps are walked; only a real climb needs a jump
	if (wp[2] - org[2] > 40.0 && len < 100.0)
		buttons |= IN_JUMP;
	// look where we are going (a little ahead), turning like a person: never a snap
	float ahead[3];
	ahead = wp;
	if (g_PathIdx[c] + 1 < g_Path[c].Length)
		g_Path[c].GetArray(g_PathIdx[c] + 1, ahead, 3);
	float want = ArcTangent2(ahead[1] - org[1], ahead[0] - org[0]) * 57.29578;
	float turn = AngleDiff(want, angles[1]) * 0.12;
	if (turn > IDLE_TURN) turn = IDLE_TURN;
	if (turn < -IDLE_TURN) turn = -IDLE_TURN;
	angles[1] += turn;
	angles[0] += AngleDiff(2.0, angles[0]) * 0.1;
	// not getting anywhere: plan again, and hop
	if (now - g_ProgAt[c] > 1.0)
	{
		if (Dist(org, g_ProgPos[c]) < 25.0)
		{
			g_PathAt[c] = 0.0;
			buttons |= IN_JUMP;
		}
		g_ProgPos[c] = org;
		g_ProgAt[c] = now;
	}
	return true;
}

// Centre of the nav area under the site, for routes: the func_bomb_target itself may be a trigger in the air.
bool SiteGoal(int site, float out[3])
{
	if (site < 0 || site >= g_SiteCount || !NavOk())
		return false;
	return BotNav_Nearest(g_SitePos[site], out);
}

// ---------------------------------------------------------------- tactics
// shortcut: there is no nav mesh here, so bots walk with the game's own movement. The tactic layer decides *who waits,
// who holds and where they look*: stagger or group the Ts, anchor the CTs on the sites, hold after the plant.


void LoadSites()
{
	g_SiteCount = 0;
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_bomb_target")) != -1 && g_SiteCount < MAX_SITES)
	{
		float o[3], mn[3], mx[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", o);
		GetEntPropVector(ent, Prop_Send, "m_vecMins", mn);
		GetEntPropVector(ent, Prop_Send, "m_vecMaxs", mx);
		for (int i = 0; i < 3; i++)
			g_SitePos[g_SiteCount][i] = o[i] + (mn[i] + mx[i]) * 0.5;
		g_SiteCount++;
	}
	static const char names[][] = { "", "", "info_player_terrorist", "info_player_counterterrorist" };
	for (int team = 2; team <= 3; team++)
	{
		float sum[3];
		int n = 0;
		sum[0] = sum[1] = sum[2] = 0.0;
		ent = -1;
		while ((ent = FindEntityByClassname(ent, names[team])) != -1)
		{
			float o[3];
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", o);
			AddVectors(sum, o, sum);
			n++;
		}
		g_HaveSpawn[team] = n > 0;
		if (n)
			ScaleVector(sum, 1.0 / n);
		g_SpawnPos[team] = sum;
	}
}

public void OnMapStart()
{
	LoadSites();
	ConVar gt = FindConVar("game_type");
	g_Tactical = g_SiteCount > 0 && gt != null && gt.IntValue == 0;
#if defined GOD
	LoadLineups();
#endif
}

public void EvRoundEnd(Event e, const char[] n, bool b)
{
	int winner = e.GetInt("winner");
	for (int team = 2; team <= 3; team++)
		g_LostRow[team] = winner == team ? 0 : g_LostRow[team] + 1;
}

// A weighted pick; a tactic that lost twice in a row is dropped for the next round, as a team that adapts would.
int Pick(int team, int a, int wa, int b, int wb, int c, int wc)
{
	if (g_LostRow[team] >= 2)
	{
		if (g_Tactic[team] == a) wa = 0;
		else if (g_Tactic[team] == b) wb = 0;
		else if (g_Tactic[team] == c) wc = 0;
	}
	int roll = GetRandomInt(1, wa + wb + wc);
	return roll <= wa ? a : (roll <= wa + wb ? b : c);
}

public Action TimerPick(Handle t)
{
	if (!Active() || !g_TuneTactics.BoolValue || !g_Tactical)
		return Plugin_Stop;
	g_Tactic[CS_TEAM_T] = Pick(CS_TEAM_T, TT_RUSH, W_RUSH, TT_DEFAULT, W_DEFAULT, TT_EXEC, W_EXEC);
	g_Tactic[CS_TEAM_CT] = Pick(CS_TEAM_CT, CT_AGGRO, 20, CT_SETUP, 55, CT_STACK, 25);
	g_StackSite = g_SiteCount > 0 ? GetRandomInt(0, g_SiteCount - 1) : 0;
	g_TargetSite = g_SiteCount > 0 ? GetRandomInt(0, g_SiteCount - 1) : 0;
	g_StageGo = g_Tactic[CS_TEAM_T] != TT_EXEC;
	g_HaveStage = false;
	float goal[3];
	if (g_Tactical && g_HaveSpawn[CS_TEAM_T] && SiteGoal(g_TargetSite, goal))
	{
		// the staging point: 60 % of the way from the T spawn to the site
		ArrayList route = new ArrayList(3);
		if (BotNav_Path(g_SpawnPos[CS_TEAM_T], goal, route) > 4)
		{
			route.GetArray(route.Length * 6 / 10, g_Stage, 3);
			g_HaveStage = true;
		}
		delete route;
	}
	if (g_TuneDebug.BoolValue)
	{
		LogMessage("bot level %d: T tactic %d (site %d, staging %s), CT tactic %d", LEVEL, g_Tactic[CS_TEAM_T], g_TargetSite, g_HaveStage ? "yes" : "no", g_Tactic[CS_TEAM_CT]);
	}
	int taken[MAX_SITES], bots = 0;
	for (int c = 1; c <= MaxClients; c++)
	{
		g_Role[c] = -1;
		PathClear(c);
		g_HoldSet[c] = false;
		g_Held[c] = false;
		if (!IsBot(c))
			continue;
		if (GetClientTeam(c) == CS_TEAM_T)
		{
			// RUSH goes at once, EXEC leaves together, DEFAULT trickles out
			float off = 0.0;
			if (g_Tactic[CS_TEAM_T] == TT_EXEC)
				off = 3.0;
			else if (g_Tactic[CS_TEAM_T] == TT_DEFAULT)
				off = GetRandomFloat(0.0, 6.0) * STAGGER;
			g_Release[c] = off;
		}
		else if (GetClientTeam(c) == CS_TEAM_CT)
			bots++;
	}
	// CTs: each takes the nearest site that still has room; the rest roam
	if (g_SiteCount > 0 && g_Tactic[CS_TEAM_CT] != CT_AGGRO)
	{
		int per = bots <= 3 ? 1 : 2;
		for (int c = 1; c <= MaxClients; c++)
		{
			if (!IsBot(c) || GetClientTeam(c) != CS_TEAM_CT)
				continue;
			float o[3];
			GetClientAbsOrigin(c, o);
			int pick = -1;
			float bd = 99999.0;
			for (int i = 0; i < g_SiteCount; i++)
			{
				int quota = g_Tactic[CS_TEAM_CT] == CT_STACK ? (i == g_StackSite ? 3 : 1) : per;
				float d = Dist(o, g_SitePos[i]);
				if (taken[i] < quota && d < bd)
				{
					bd = d;
					pick = i;
				}
			}
			if (pick >= 0)
			{
				taken[pick]++;
				g_Role[c] = pick;
			}
		}
	}
	return Plugin_Stop;
}

// The longest open line from `from`, within 80 degrees of `toward`: where a person would hold.
float Sightline(const float from[3], const float toward[3])
{
	float eye[3], d[3], base[3], end[3];
	eye = from;
	eye[2] += 60.0;
	SubtractVectors(toward, from, d);
	GetVectorAngles(d, base);
	float bestLen = -1.0, bestYaw = base[1];
	for (float off = -80.0; off <= 80.0; off += 10.0)
	{
		float a[3], f[3];
		a[0] = 0.0; a[1] = base[1] + off; a[2] = 0.0;
		GetAngleVectors(a, f, NULL_VECTOR, NULL_VECTOR);
		end[0] = eye[0] + f[0] * 2500.0; end[1] = eye[1] + f[1] * 2500.0; end[2] = eye[2];
		TR_TraceRayFilter(eye, end, MASK_SOLID, RayType_EndPoint, OnlyWorld, 0);
		TR_GetEndPosition(end);
		float len = Dist(eye, end);
		if (len > bestLen)
		{
			bestLen = len;
			bestYaw = a[1];
		}
	}
	return bestYaw;
}

bool Threat(int team, const float org[3], float range)
{
	for (int e = 1; e <= MaxClients; e++)
		if (Alive(e) && GetClientTeam(e) != team && Known(team, e) && Dist(org, g_KnownPos[team][e]) < range)
			return true;
	return false;
}

// True when the bot should stand where it is this tick (walking, watching its angle); tempo and holds of the tactic.
bool TacticMove(int c, int &buttons, float vel[3], float dest[3], bool &hasDest)
{
	g_Held[c] = false;
	hasDest = false;
	if (!g_TuneTactics.BoolValue || !g_Tactical || g_RoundStart <= 0.0)
		return false;
	float now = GetGameTime(), org[3];
	int team = GetClientTeam(c);
	GetClientAbsOrigin(c, org);
	bool hold = false;
	bool fight = Threat(team, org, 1500.0);

	if (team == CS_TEAM_T)
	{
		if (g_Planted && GetPlayerWeaponSlot(c, 4) < 1 && Dist(org, g_BombPos) < 1100.0)
		{
			hold = true;                                         // post-plant: hold an angle on the bomb
			if (!g_HoldSet[c])
			{
				float toward[3];
				toward = g_HaveSpawn[CS_TEAM_CT] ? g_SpawnPos[CS_TEAM_CT] : g_BombPos;
				g_HoldYaw[c] = Sightline(org, toward);
				g_HoldSet[c] = true;
			}
		}
		else if (!fight && now - g_RoundStart < g_Release[c])
			hold = true;                                         // waits its turn to leave
		else if (!fight && g_Tactic[team] != TT_RUSH && !g_Planted && NavOk())
		{
			// execute: gather at the staging point, then everybody goes in; otherwise straight for the site
			float site[3];
			bool toStage = g_Tactic[team] == TT_EXEC && g_HaveStage && !g_StageGo;
			if (toStage)
			{
				dest = g_Stage;
				hasDest = true;
				if (Dist(org, g_Stage) < 250.0)
					hold = true;                                     // there: wait for the rest
			}
			else if (SiteGoal(g_TargetSite, site) && Dist(org, site) > 450.0)
			{
				dest = site;
				hasDest = true;
			}
		}
		else if (!fight && g_Tactic[team] != TT_RUSH && g_HaveCentroid[team] && !g_Planted)
		{
			float leash = g_TuneLeash.FloatValue * LEASH_MUL * (g_Tactic[team] == TT_EXEC ? 0.55 : 1.2);
			// the one far ahead of its team waits for them; the ones behind keep going
			if (Dist(org, g_Centroid[team]) > leash && g_HaveSpawn[team] && Dist(org, g_SpawnPos[team]) > Dist(g_Centroid[team], g_SpawnPos[team]))
				hold = true;
		}
	}
	else if (team == CS_TEAM_CT)
	{
		if (!g_Planted && g_Role[c] >= 0 && NavOk() && now - g_RoundStart > 2.0)
		{
			// walk to a hiding spot near the site, then hold the longest line from there
			if (!g_HoldSet[c])
			{
				ArrayList spots = new ArrayList(3);
				float best[3], toward[3];
				bool found = false;
				if (BotNav_Spots(g_SitePos[g_Role[c]], 650.0, spots) > 0)
				{
					int pick = (c * 7 + g_Role[c]) % spots.Length;
					spots.GetArray(pick, best, 3);
					found = true;
				}
				delete spots;
				g_AnchorPos[c] = found ? best : g_SitePos[g_Role[c]];
				toward = g_HaveSpawn[CS_TEAM_T] ? g_SpawnPos[CS_TEAM_T] : g_SitePos[g_Role[c]];
				g_HoldYaw[c] = Sightline(g_AnchorPos[c], toward);
				g_HoldSet[c] = true;
			}
			if (Dist(org, g_AnchorPos[c]) > 70.0 && !fight)
			{
				dest = g_AnchorPos[c];
				hasDest = true;
			}
			else
				hold = true;
		}
		else if (!g_Planted && g_Role[c] >= 0 && now - g_RoundStart > 5.0 && Dist(org, g_SitePos[g_Role[c]]) < 500.0)
		{
			hold = true;                                         // anchors its site on the longest line towards the Ts
			if (!g_HoldSet[c])
			{
				float toward[3];
				toward = g_HaveSpawn[CS_TEAM_T] ? g_SpawnPos[CS_TEAM_T] : g_SitePos[g_Role[c]];
				g_HoldYaw[c] = Sightline(org, toward);
				g_HoldSet[c] = true;
			}
		}
		else if (g_Planted && !fight && g_HaveCentroid[team] && g_HaveSpawn[team])
		{
			// the retake goes in together
			float leash = g_TuneLeash.FloatValue * LEASH_MUL;
			if (Dist(org, g_Centroid[team]) > leash && Dist(org, g_BombPos) < Dist(g_Centroid[team], g_BombPos))
				hold = true;
			else if (NavOk() && Dist(org, g_BombPos) > 500.0)
			{
				dest = g_BombPos;                                // the retake goes in together, on the route
				hasDest = true;
			}
		}
	}
	if (hold)
	{
		g_Held[c] = true;
		vel[0] = vel[1] = 0.0;
		buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP);
		buttons |= IN_SPEED;
		return true;
	}
	// sneak when the enemy is known to be close
	if (Threat(team, org, 900.0))
		buttons |= IN_SPEED;
	return false;
}

// ---------------------------------------------------------------- aim

public Action OnPlayerRunCmd(int c, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!Active() || !IsBot(c))
		return Plugin_Continue;
	Action a = Think(c, buttons, vel, angles, weapon);
	g_PrevYaw[c] = angles[1];
	return a;
}

Action Think(int c, int &buttons, float vel[3], float angles[3], int &weapon)
{
	float now = GetGameTime();

	// stuck against a corner or stairs while trying to walk: jiggle free, as a person would
	if (now >= g_StuckAt[c])
	{
		float org[3];
		GetClientAbsOrigin(c, org);
		if (g_RoundStart > 0.0 && g_Phase[c] == 0 && !g_Held[c] && (buttons & IN_FORWARD) && Dist(org, g_StuckPos[c]) < 12.0 && now > g_UnstuckUntil[c])
		{
			g_UnstuckUntil[c] = now + 0.5;
			g_StrafeDir[c] = GetRandomInt(0, 1) ? 1.0 : -1.0;
		}
		g_StuckPos[c] = org;
		g_StuckAt[c] = now + 1.5;
	}
	if (now < g_UnstuckUntil[c])
	{
		buttons |= IN_JUMP;
		vel[1] = g_StrafeDir[c] * 250.0;
	}

	if (RunPlan(c, buttons, vel, angles, weapon))
		return Plugin_Changed;

	// the bots' own idea of throwing grenades is not allowed: the evaluator decides
	if (ActiveNade(c) != N_NONE)
	{
		buttons &= ~(IN_ATTACK | IN_ATTACK2);
		weapon = Gun(c);
		return Plugin_Changed;
	}

	if (now >= g_NextEval[c])
	{
		g_NextEval[c] = now + 0.4 + GetRandomFloat(0.0, 0.2);
		Evaluate(c);
	}

	float dest[3];
	bool hasDest;
	bool held = TacticMove(c, buttons, vel, dest, hasDest);
	// walk the route the tactic asks for; the game's own movement is put back if an enemy shows up
	float keepV0 = vel[0], keepV1 = vel[1];
	int keepButtons = buttons;
	bool navWalk = false;
	if (hasDest && !held && PathTo(c, dest))
		navWalk = PathStep(c, buttons, vel, angles);
	else if (g_Path[c] != null)
		PathClear(c);
	int active = ActiveWeapon(c);
	float eye[3], punch[3];
	GetClientEyePosition(c, eye);
	GetEntPropVector(c, Prop_Send, "m_aimPunchAngle", punch);
	bool changed = navWalk;

	// a visible enemy inside the field of view, the one closest to the crosshair
	int best = 0;
	float bestDiff = 100.0, goal[3], bgoal[3];
	ConVar ffa = FindConVar("mp_teammates_are_enemies");
	bool all = ffa != null && ffa.BoolValue;
	for (int e = 1; e <= MaxClients; e++)
	{
		if (e == c || !Alive(e) || (!all && GetClientTeam(e) == GetClientTeam(c)))
			continue;
		float head[3], body[3], org[3], d[3], want[3];
		GetClientEyePosition(e, head);
		head[2] -= 2.0;
		GetClientAbsOrigin(e, org);
		body = org;
		body[2] += 40.0;
		if (Clear(eye, head))
			goal = head;
		else if (Clear(eye, body))
			goal = body;
		else
			continue;
		SubtractVectors(goal, eye, d);
		GetVectorAngles(d, want);
		float diff = FloatAbs(AngleDiff(want[1], angles[1])) + FloatAbs(AngleDiff(want[0], angles[0]));
		if (diff < bestDiff)
		{
			bestDiff = diff;
			best = e;
			bgoal = goal;
		}
	}

	if (best != 0 && navWalk)
	{
		vel[0] = keepV0;
		vel[1] = keepV1;
		buttons = keepButtons;
	}
	if (best == 0)
	{
		g_Tgt[c] = 0;
		// hold the angle where a teammate last saw an enemy, if it is in front of us: pre-aim, never a half turn
		int hunt = 0;
		float huntD = 1500.0, hp[3], hd[3], hw[3];
		int team = GetClientTeam(c);
		for (int e = 1; e <= MaxClients; e++)
		{
			if (!Alive(e) || GetClientTeam(e) == team || GetClientTeam(e) < 2 || GetGameTime() - g_KnownAt[team][e] > 2.5)
				continue;
			float dd = Dist(eye, g_KnownPos[team][e]);
			if (dd < huntD)
			{
				huntD = dd;
				hunt = e;
			}
		}
		if (hunt)
		{
			hp = g_KnownPos[team][hunt];
			hp[2] += 24.0;
			SubtractVectors(hp, eye, hd);
			GetVectorAngles(hd, hw);
			if (FloatAbs(AngleDiff(hw[1], angles[1])) < 60.0)
			{
				angles[0] += AngleDiff(hw[0], angles[0]) * EASE * 0.5;
				angles[1] += AngleDiff(hw[1], angles[1]) * EASE * 0.5;
				return Plugin_Changed;
			}
		}
		if (held)
		{
			// holding: watch the line, with a slow look to either side
			float wy = g_HoldYaw[c] + 12.0 * Sine(now * 0.6 + c);
			angles[0] += AngleDiff(2.0, angles[0]) * 0.12;
			angles[1] += AngleDiff(wy, angles[1]) * 0.08;
			return Plugin_Changed;
		}
		// nobody turns on the spot at flick speed to look at nothing
		float turn = AngleDiff(angles[1], g_PrevYaw[c]);
		if (g_PrevYaw[c] != 0.0 && FloatAbs(turn) > IDLE_TURN)
		{
			angles[1] = g_PrevYaw[c] + (turn > 0.0 ? IDLE_TURN : -IDLE_TURN);
			changed = true;
		}
		// the eyes stay level: no staring at the floor
		if (angles[0] > 12.0)
		{
			angles[0] -= (angles[0] - 4.0) * 0.2;
			changed = true;
		}
		return changed ? Plugin_Changed : Plugin_Continue;
	}

	if (g_Tgt[c] != best)
	{
		g_Tgt[c] = best;
		g_Since[c] = now;
		g_React[c] = GetRandomFloat(REACT_MIN, REACT_MAX) * g_TuneReact.FloatValue;
		// the first flick lands a little off and corrects, more when the target is running
		float ev[3];
		GetEntPropVector(best, Prop_Data, "m_vecVelocity", ev);
		float mag = ACQ_ERR * g_TuneAim.FloatValue * (1.0 + GetVectorLength(ev) / 250.0);
		g_ErrP[c] = GetRandomFloat(-mag, mag);
		g_ErrY[c] = GetRandomFloat(-mag, mag);
	}
	if (now - g_Since[c] < g_React[c] || now < g_PauseUntil[c] || !IsGun(active))
		return Plugin_Continue;

	float d2[3], want2[3];
	SubtractVectors(bgoal, eye, d2);
	GetVectorAngles(d2, want2);
	// aim opposite to twice the punch so the spray goes straight
	float gp = want2[0] - punch[0] * 2.0 + g_ErrP[c] + GetRandomFloat(-JITTER, JITTER);
	float gy = want2[1] - punch[1] * 2.0 + g_ErrY[c] + GetRandomFloat(-JITTER, JITTER);
	g_ErrP[c] *= ERR_DECAY;
	g_ErrY[c] *= ERR_DECAY;
	angles[0] += AngleDiff(gp, angles[0]) * EASE;
	angles[1] += AngleDiff(gy, angles[1]) * EASE;
	if (angles[0] > 89.0) angles[0] = 89.0;
	if (angles[0] < -89.0) angles[0] = -89.0;

	float err = FloatAbs(AngleDiff(gp, angles[0])) + FloatAbs(AngleDiff(gy, angles[1]));
	float dist = Dist(eye, bgoal);
	if (err >= FIRE_ERR && dist < 450.0 && now >= g_UnstuckUntil[c])
	{
		// close duels: strafe while the aim settles, then stop to shoot
		if (now >= g_StrafeUntil[c])
		{
			g_StrafeUntil[c] = now + GetRandomFloat(0.25, 0.6);
			g_StrafeDir[c] = GetRandomInt(0, 1) ? 1.0 : -1.0;
		}
		vel[1] = g_StrafeDir[c] * 250.0;
	}
	if (err < FIRE_ERR)
	{
		// never through a teammate
		TR_TraceRayFilter(eye, angles, MASK_SHOT, RayType_Infinite, NotSelf, c);
		bool friend = false;
		if (TR_DidHit())
		{
			int h = TR_GetEntityIndex();
			friend = h >= 1 && h <= MaxClients && !all && GetClientTeam(h) == GetClientTeam(c);
		}
		bool scoped = !IsSniper(active) || GetEntProp(c, Prop_Send, "m_bIsScoped") != 0;
		if (!friend && scoped)
		{
			g_Burst[c]++;
			// far away: short bursts; close: hold the trigger
			if (dist < 900.0 || (g_Burst[c] % 9) < 4)
			{
				buttons |= IN_ATTACK;
				if (dist > 500.0)
					vel[0] = vel[1] = 0.0;        // stop to shoot
			}
		}
	}
	return Plugin_Changed;
}
