/*
		Finale Can't Spawn Glitch Fix (C) 2014 Michael Busby
		All trademarks are property of their respective owners.
 
		This program is free software: you can redistribute it and/or modify it
		under the terms of the GNU General Public License as published by the
		Free Software Foundation, either version 3 of the License, or (at your
		option) any later version.
 
		This program is distributed in the hope that it will be useful, but
		WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
		General Public License for more details.
 
		You should have received a copy of the GNU General Public License along
		with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
 
#include <sourcemod>
 
// Offset of the prop we're looking for from m_ghostSpawnState,
// since its relative offset should be more stable than other stuff...
const OFFS_FROM_SPAWNSTATE = 0x26;
new g_SawSurvivorsOutsideBattlefieldOffset;
new bool:g_bAutoFixThisMap = false;

public Plugin:myinfo =
{
		name = "Finale Can't Spawn Glitch Fix",
		author = "ProdigySim",
		description = "Fixing Waiting For Survivors To Start The Finale or w/e",
		version = "1.1",
		url = "https://github.com/ConfoglTeam/ProMod"
}
 
public OnPluginStart()
{
	RegAdminCmd("sm_fix_wff", AdminFixWaitingForFinale, ADMFLAG_GENERIC, "Manually fix the 'Waiting for finale to start' issue for all infected.");
	
	g_SawSurvivorsOutsideBattlefieldOffset = FindSendPropOffs("CTerrorPlayer", "m_ghostSpawnState") + OFFS_FROM_SPAWNSTATE;
	
	HookEvent("round_start", OnRoundStart);
}

public OnMapStart()
{
	decl String:mapname[200];
	g_bAutoFixThisMap = false;
	if(GetCurrentMap(mapname, sizeof(mapname)) > 0)
	{
		if(StrEqual("uf4_airfield", mapname))
		{
			g_bAutoFixThisMap = true;
		}
	}
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bAutoFixThisMap) 
	{
		FixAllInfected();
	}
}

FixAllInfected()
{
	PrintToChatAll("Fixing Waiting For Finale to Start issue for all infected");
	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3) 
		{
			SetSeenSurvivorsState(i, true);
			// This part shouldn't be necessary, but just for good measure:
			// Remove the "WAIT_FOR_FINALE" spawn flag
			SetSpawnFlags(i, GetSpawnFlags(i) & ~4);
		}
	}
}


public Action:AdminFixWaitingForFinale(client, args)
{
	FixAllInfected();
}

// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"
stock SetSpawnFlags(entity, flags)
{
	SetEntProp(entity, Prop_Send, "m_ghostSpawnState", flags);
}

stock GetSpawnFlags(entity)
{
	return GetEntProp(entity, Prop_Send, "m_ghostSpawnState");
}

stock bool:GetSeenSurvivorsState(entity)
{
	// m_ghostSawSurvivorsOutsideFinaleArea
	return bool:GetEntData(entity, g_SawSurvivorsOutsideBattlefieldOffset, 1);
}
stock SetSeenSurvivorsState(entity, bool:seen)
{
	// m_ghostSawSurvivorsOutsideFinaleArea
	SetEntData(entity, g_SawSurvivorsOutsideBattlefieldOffset, seen ? 1: 0, 1);
}
