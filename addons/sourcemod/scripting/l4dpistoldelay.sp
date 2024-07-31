/*
	SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
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
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "L4D Pistol Delayer",
	author = "Griffin, darkid",
	description = "Limits pistol fire rate & allows slow fire while holding m1.",
	version = "0.3",
    url = "https://github.com/jacob404/Pro-Mod-4.0/releases/latest"
};

new Float:g_fNextAttack[MAXPLAYERS + 1];
new Float:g_fNextAutoFire[MAXPLAYERS + 1];
new Handle:g_hPistolDelayDualies = INVALID_HANDLE;
new Handle:g_hPistolDelaySingle = INVALID_HANDLE;
new Handle:g_hPistolDelayIncapped = INVALID_HANDLE;
new Handle:g_hPistolSlowFire = INVALID_HANDLE;

public OnPluginStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
	}
	// Defaults are from fastest firing on 30tick
	g_hPistolDelayDualies = CreateConVar("l4d_pistol_delay_dualies", "0.1", "Minimum time (in seconds) between dual pistol shots",
		FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hPistolDelaySingle = CreateConVar("l4d_pistol_delay_single", "0.2", "Minimum time (in seconds) between single pistol shots",
		FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hPistolDelayIncapped = CreateConVar("l4d_pistol_delay_incapped", "0.3", "Minimum time (in seconds) between pistol shots while incapped",
		FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
	g_hPistolSlowFire = CreateConVar("l4d_pistol_autofire_rate", "0.3", "Auto-fire rate for dualies (seconds per shot) while holding mouse1.",
		FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);

	HookEvent("weapon_fire", Event_WeaponFire);
}

public OnMapStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		g_fNextAttack[client] = 0.0;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThink, Hook_OnPostThinkPost);
	g_fNextAttack[client] = 0.0;
}

public Hook_OnPostThinkPost(client)
{
	// Human survivors only
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
	new activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEdict(activeweapon)) return;
	decl String:weaponname[64];
	GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
	if (strcmp(weaponname, "weapon_pistol") != 0) return;

	new Float:old_value = GetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack");
	new Float:new_value = g_fNextAttack[client];

	// Never accidentally speed up fire rate
	if (new_value > old_value)
	{
		// PrintToChatAll("Readjusting delay: Old=%f, New=%f", old_value, new_value);
		SetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack", new_value);
	}
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
	new activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEdict(activeweapon)) return;
	decl String:weaponname[64];
	GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
	if (strcmp(weaponname, "weapon_pistol") != 0) return;
	// new dualies = GetEntProp(activeweapon, Prop_Send, "m_hasDualWeapons");
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		g_fNextAttack[client] = GetGameTime() + GetConVarFloat(g_hPistolDelayIncapped);
	}
	// What is the difference between m_isDualWielding and m_hasDualWeapons ?
	else if (GetEntProp(activeweapon, Prop_Send, "m_isDualWielding"))
	{
		g_fNextAttack[client] = GetGameTime() + GetConVarFloat(g_hPistolDelayDualies);
	}
	else
	{
		g_fNextAttack[client] = GetGameTime() + GetConVarFloat(g_hPistolDelaySingle);
	}
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (client <= 0 || client > MaxClients) return Plugin_Continue;
	if (!IsClientInGame(client)) return Plugin_Continue;
	if (IsFakeClient(client)) return Plugin_Continue;
	if (GetClientTeam(client) != 2) return Plugin_Continue;
	new activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEdict(activeweapon)) return Plugin_Continue;
	decl String:weaponname[64];
	GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
	if (strcmp(weaponname, "weapon_pistol") != 0) return Plugin_Continue;

	if (buttons & IN_RELOAD == IN_RELOAD) {
		// Otherwise the user can't reload while their pistol is on cooldown.
		// If the delay is longer than the reload anim (~2.4 sec), they will not get credit for reloading until the cooldown wears off.
		// The reload will be canceled if weapons are changed during this time.
		SetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
	}

	if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) return Plugin_Continue;
	if (!GetEntProp(activeweapon, Prop_Send, "m_isDualWielding")) return Plugin_Continue;

	if (buttons & IN_ATTACK == IN_ATTACK) {
		if (g_fNextAutoFire[client] == 0.0) { // Signal
			g_fNextAutoFire[client] = GetGameTime() + GetConVarFloat(g_hPistolSlowFire);
		} else if (GetGameTime() > g_fNextAutoFire[client]) {
			buttons &= ~IN_ATTACK; // Release M1 for them so the game thinks that they're clicking again next frame.
			g_fNextAutoFire[client] = GetGameTime() + GetConVarFloat(g_hPistolSlowFire);
			EmitSoundToAll("weapons/pistol/gunfire/pistol_dual_fire.wav", client, SNDCHAN_VOICE);
			return Plugin_Changed;
		}
	} else {
		g_fNextAutoFire[client] = 0.0; // Signals client not attacking
	}

	return Plugin_Continue;
}
