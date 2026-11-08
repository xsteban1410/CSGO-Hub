// SPDX-License-Identifier: GPL-3.0-or-later
// botnav: the map's navigation mesh as a graph, with a path finder, for other plugins (see botnav.inc).
// The app writes the graph (needs = ["nav"]); this plugin only reads it, from SourceMod's data folder.
#pragma semicolon 1
#pragma newdecls required

#pragma dynamic 65536

#include <sourcemod>
#include <csls>

public Plugin myinfo = { name = "botnav", author = "xsteban1410", description = "Navigation graph and path finder", version = "1.0.0", url = "https://github.com/xsteban1410/CSGO-Hub" };

#define MAX_AREAS 12000
#define MAX_ADJ 120000
#define MAX_SPOTS 12000
#define MAX_PLACES 512
#define MAX_HEAP 400000

int g_Count;
float g_Min[MAX_AREAS][2];
float g_Max[MAX_AREAS][2];
float g_Cen[MAX_AREAS][3];
int g_Place[MAX_AREAS];
int g_AdjStart[MAX_AREAS];
int g_AdjN[MAX_AREAS];
int g_Adj[MAX_ADJ];
int g_AdjTotal;
float g_Spot[MAX_SPOTS][3];
int g_SpotCount;
char g_PlaceName[MAX_PLACES][48];
int g_PlaceCount;
StringMap g_Index;
bool g_Ready;

// A* work arrays
float g_G[MAX_AREAS];
int g_From[MAX_AREAS];
bool g_Closed[MAX_AREAS];
float g_HKey[MAX_HEAP];
int g_HNode[MAX_HEAP];
int g_HSize;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	RegPluginLibrary("botnav");
	CreateNative("BotNav_Ready", NativeReady);
	CreateNative("BotNav_Nearest", NativeNearest);
	CreateNative("BotNav_Path", NativePath);
	CreateNative("BotNav_PlaceAt", NativePlaceAt);
	CreateNative("BotNav_PlacePos", NativePlacePos);
	CreateNative("BotNav_Spots", NativeSpots);
	return APLRes_Success;
}

public void OnMapStart()
{
	g_Ready = false;
	g_Count = g_AdjTotal = g_SpotCount = g_PlaceCount = 0;
	char map[96], path[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	int slash = FindCharInString(map, '/', true);
	if (slash != -1)
		strcopy(map, sizeof(map), map[slash + 1]);
	if (!CSLS_ExportPath("nav", map, path, sizeof(path)))
	{
		LogMessage("botnav: no graph for %s (is the app extracting 'nav'? run deploy)", map);
		return;
	}
	g_Ready = Load(path);
	if (g_Ready)
		LogMessage("botnav: %s loaded: %d areas, %d links, %d hiding spots, %d places", map, g_Count, g_AdjTotal, g_SpotCount, g_PlaceCount);
}

// Next space-separated token of `s` from `at`; false at the end.
bool Next(const char[] s, int &at, char[] tok, int len)
{
	if (at < 0)
		return false;
	int r = BreakString(s[at], tok, len);
	at = r == -1 ? -1 : at + r;
	return tok[0] != 0;
}

bool Load(const char[] path)
{
	File f = OpenFile(path, "r");
	if (f == null)
		return false;
	delete g_Index;
	g_Index = new StringMap();
	char line[4096], tok[48], key[16];
	// areas first: C and H lines refer to them by id
	while (f.ReadLine(line, sizeof(line)))
	{
		if (line[0] == 'P' && line[1] == ' ' && g_PlaceCount < MAX_PLACES - 1)
		{
			int at = 2;
			Next(line, at, tok, sizeof(tok));
			int pid = StringToInt(tok);
			if (pid < 1 || pid >= MAX_PLACES)
				continue;
			Next(line, at, g_PlaceName[pid], sizeof(g_PlaceName[]));
			TrimString(g_PlaceName[pid]);
			if (pid > g_PlaceCount)
				g_PlaceCount = pid;
		}
		else if (line[0] == 'A' && line[1] == ' ' && g_Count < MAX_AREAS)
		{
			int at = 2;
			float v[8];
			Next(line, at, tok, sizeof(tok));
			int id = StringToInt(tok);
			g_AdjN[g_Count] = 0;
			g_AdjStart[g_Count] = 0;
			for (int i = 0; i < 8; i++)
			{
				Next(line, at, tok, sizeof(tok));
				v[i] = StringToFloat(tok);
			}
			// v: nw xyz, se xyz, ne z, sw z, then place and attributes
			Next(line, at, tok, sizeof(tok));
			g_Place[g_Count] = StringToInt(tok);
			g_Min[g_Count][0] = v[0] < v[3] ? v[0] : v[3];
			g_Max[g_Count][0] = v[0] < v[3] ? v[3] : v[0];
			g_Min[g_Count][1] = v[1] < v[4] ? v[1] : v[4];
			g_Max[g_Count][1] = v[1] < v[4] ? v[4] : v[1];
			g_Cen[g_Count][0] = (v[0] + v[3]) * 0.5;
			g_Cen[g_Count][1] = (v[1] + v[4]) * 0.5;
			g_Cen[g_Count][2] = (v[2] + v[5] + v[6] + v[7]) * 0.25;
			IntToString(id, key, sizeof(key));
			g_Index.SetValue(key, g_Count);
			g_Count++;
		}
		else if (g_Count > 0 && (line[0] == 'C' || line[0] == 'H') && line[1] == ' ')
			break;
	}
	// the line that stopped the loop is the first C or H; process it and the rest
	do
	{
		if (line[0] == 'C' && line[1] == ' ')
		{
			int at = 2, idx, to;
			Next(line, at, tok, sizeof(tok));
			if (!g_Index.GetValue(tok, idx))
				continue;
			g_AdjStart[idx] = g_AdjTotal;
			while (Next(line, at, tok, sizeof(tok)))
				if (g_Index.GetValue(tok, to) && g_AdjTotal < MAX_ADJ)
					g_Adj[g_AdjTotal++] = to;
			g_AdjN[idx] = g_AdjTotal - g_AdjStart[idx];
		}
		else if (line[0] == 'H' && line[1] == ' ' && g_SpotCount < MAX_SPOTS)
		{
			int at = 2;
			Next(line, at, tok, sizeof(tok));
			for (int i = 0; i < 3; i++)
			{
				Next(line, at, tok, sizeof(tok));
				g_Spot[g_SpotCount][i] = StringToFloat(tok);
			}
			g_SpotCount++;
		}
	}
	while (f.ReadLine(line, sizeof(line)));
	delete f;
	return g_Count > 0;
}

// ---------------------------------------------------------------- geometry

// Index of the area under `pos`, else the one whose box is closest. -1 without a graph.
int AreaAt(const float pos[3])
{
	int best = -1;
	float bestD = 99999999.0;
	for (int i = 0; i < g_Count; i++)
	{
		float dx = 0.0, dy = 0.0;
		if (pos[0] < g_Min[i][0]) dx = g_Min[i][0] - pos[0];
		else if (pos[0] > g_Max[i][0]) dx = pos[0] - g_Max[i][0];
		if (pos[1] < g_Min[i][1]) dy = g_Min[i][1] - pos[1];
		else if (pos[1] > g_Max[i][1]) dy = pos[1] - g_Max[i][1];
		float dz = pos[2] - g_Cen[i][2];
		// height counts more: floors above each other must not be confused
		float d = dx * dx + dy * dy + dz * dz * 4.0;
		if (d < bestD)
		{
			bestD = d;
			best = i;
		}
	}
	return best;
}

float Clampf(float v, float lo, float hi)
{
	return v < lo ? lo : (v > hi ? hi : v);
}

// The point where a walker leaves area `a` for neighbour `b`: the middle of the stretch they share.
void Portal(int a, int b, float out[3])
{
	float x = Clampf(g_Cen[a][0], g_Min[b][0], g_Max[b][0]);
	float y = Clampf(g_Cen[a][1], g_Min[b][1], g_Max[b][1]);
	x = Clampf(x, g_Min[a][0], g_Max[a][0]);
	y = Clampf(y, g_Min[a][1], g_Max[a][1]);
	out[0] = x;
	out[1] = y;
	out[2] = g_Cen[b][2];
}

float Cost(int a, int b)
{
	float dx = g_Cen[a][0] - g_Cen[b][0], dy = g_Cen[a][1] - g_Cen[b][1], dz = g_Cen[a][2] - g_Cen[b][2];
	float d = SquareRoot(dx * dx + dy * dy + dz * dz);
	// a drop is fine, a climb is slow
	return dz < 0.0 ? d : d + dz * 0.5;
}

// ---------------------------------------------------------------- A*

void HeapPush(float key, int node)
{
	if (g_HSize >= MAX_HEAP)
		return;
	int i = g_HSize++;
	while (i > 0)
	{
		int p = (i - 1) / 2;
		if (g_HKey[p] <= key)
			break;
		g_HKey[i] = g_HKey[p];
		g_HNode[i] = g_HNode[p];
		i = p;
	}
	g_HKey[i] = key;
	g_HNode[i] = node;
}

int HeapPop()
{
	int top = g_HNode[0];
	g_HSize--;
	if (g_HSize > 0)
	{
		float key = g_HKey[g_HSize];
		int node = g_HNode[g_HSize];
		int i = 0;
		for (;;)
		{
			int c = i * 2 + 1;
			if (c >= g_HSize)
				break;
			if (c + 1 < g_HSize && g_HKey[c + 1] < g_HKey[c])
				c++;
			if (g_HKey[c] >= key)
				break;
			g_HKey[i] = g_HKey[c];
			g_HNode[i] = g_HNode[c];
			i = c;
		}
		g_HKey[i] = key;
		g_HNode[i] = node;
	}
	return top;
}

// Area indexes from `s` to `t` into `route` (start first). False when unreachable.
bool FindRoute(int s, int t, ArrayList route)
{
	for (int i = 0; i < g_Count; i++)
	{
		g_G[i] = 99999999.0;
		g_From[i] = -1;
		g_Closed[i] = false;
	}
	g_HSize = 0;
	g_G[s] = 0.0;
	HeapPush(Cost(s, t), s);
	while (g_HSize > 0)
	{
		int cur = HeapPop();
		if (g_Closed[cur])
			continue;
		if (cur == t)
		{
			// walk back
			ArrayList back = new ArrayList();
			for (int n = t; n != -1; n = g_From[n])
				back.Push(n);
			for (int i = back.Length - 1; i >= 0; i--)
				route.Push(back.Get(i));
			delete back;
			return true;
		}
		g_Closed[cur] = true;
		for (int k = 0; k < g_AdjN[cur]; k++)
		{
			int nb = g_Adj[g_AdjStart[cur] + k];
			if (g_Closed[nb])
				continue;
			float ng = g_G[cur] + Cost(cur, nb);
			if (ng < g_G[nb])
			{
				g_G[nb] = ng;
				g_From[nb] = cur;
				HeapPush(ng + Cost(nb, t), nb);
			}
		}
	}
	return false;
}

// ---------------------------------------------------------------- natives

public int NativeReady(Handle plugin, int params)
{
	return g_Ready;
}

public int NativeNearest(Handle plugin, int params)
{
	if (!g_Ready)
		return false;
	float pos[3];
	GetNativeArray(1, pos, 3);
	int a = AreaAt(pos);
	if (a < 0)
		return false;
	SetNativeArray(2, g_Cen[a], 3);
	return true;
}

public int NativePath(Handle plugin, int params)
{
	if (!g_Ready)
		return 0;
	float from[3], to[3];
	GetNativeArray(1, from, 3);
	GetNativeArray(2, to, 3);
	ArrayList path = view_as<ArrayList>(GetNativeCell(3));
	int s = AreaAt(from), t = AreaAt(to);
	if (s < 0 || t < 0)
		return 0;
	ArrayList route = new ArrayList();
	int n = 0;
	if (FindRoute(s, t, route))
	{
		for (int i = 0; i + 1 < route.Length; i++)
		{
			float p[3];
			Portal(route.Get(i), route.Get(i + 1), p);
			path.PushArray(p, 3);
			n++;
		}
		path.PushArray(g_Cen[t], 3);
		n++;
	}
	delete route;
	return n;
}

public int NativePlaceAt(Handle plugin, int params)
{
	if (!g_Ready)
		return false;
	float pos[3];
	GetNativeArray(1, pos, 3);
	int a = AreaAt(pos);
	if (a < 0 || g_Place[a] < 1 || g_Place[a] >= MAX_PLACES || !g_PlaceName[g_Place[a]][0])
		return false;
	SetNativeString(2, g_PlaceName[g_Place[a]], GetNativeCell(3));
	return true;
}

public int NativePlacePos(Handle plugin, int params)
{
	if (!g_Ready)
		return false;
	char name[48];
	GetNativeString(1, name, sizeof(name));
	int pid = 0;
	for (int p = 1; p <= g_PlaceCount; p++)
		if (StrEqual(g_PlaceName[p], name, false))
			pid = p;
	if (!pid)
		return false;
	float sum[3], n = 0.0;
	for (int i = 0; i < g_Count; i++)
		if (g_Place[i] == pid)
		{
			for (int k = 0; k < 3; k++)
				sum[k] += g_Cen[i][k];
			n += 1.0;
		}
	if (n == 0.0)
		return false;
	for (int k = 0; k < 3; k++)
		sum[k] /= n;
	// the middle of a place may be a wall: the area of the place closest to it is where one can stand
	int best = -1;
	float bd = 99999999.0;
	for (int i = 0; i < g_Count; i++)
		if (g_Place[i] == pid)
		{
			float dx = g_Cen[i][0] - sum[0], dy = g_Cen[i][1] - sum[1];
			if (dx * dx + dy * dy < bd)
			{
				bd = dx * dx + dy * dy;
				best = i;
			}
		}
	SetNativeArray(2, g_Cen[best], 3);
	return true;
}

public int NativeSpots(Handle plugin, int params)
{
	if (!g_Ready)
		return 0;
	float pos[3];
	GetNativeArray(1, pos, 3);
	float radius = view_as<float>(GetNativeCell(2));
	ArrayList out = view_as<ArrayList>(GetNativeCell(3));
	int n = 0;
	for (int i = 0; i < g_SpotCount; i++)
		if (GetVectorDistance(pos, g_Spot[i]) <= radius)
		{
			out.PushArray(g_Spot[i], 3);
			n++;
		}
	return n;
}
