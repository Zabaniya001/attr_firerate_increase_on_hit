#include <sourcemod>

#include <tf2>
#include <tf2_stocks>

#include <sdkhooks>

#include <tf2attributes>
#include <tf_custom_attributes>

#include <stocksoup/var_strings>
#include <tf2utils>

#pragma semicolon 1;
#pragma newdecls required;

#define PLUGIN_NAME 		"[TF2-CA] Attack Speed Bonus"
#define PLUGIN_AUTHOR 		"Zabaniya001"
#define PLUGIN_DESCRIPTION 	"Custom Attribute that utilizes Nosoop's CA Framework. The more you hit someone the more your Attack Speed & Reload Speed increase."
#define PLUGIN_VERSION 		"1.0.0"
#define PLUGIN_URL 			"https://alliedmods.net"

public Plugin myinfo = {
	name 		= 	PLUGIN_NAME,
	author 		= 	PLUGIN_AUTHOR,
	description = 	PLUGIN_DESCRIPTION,
	version 	= 	PLUGIN_VERSION,
	url 		= 	PLUGIN_URL
}

#define TF2_MAXPLAYERS 36
#define MAX_SLOTS 4

// ||─────────────────────────────────────────────────────────────────────────||
// ||                             GLOBAL VARIABLES                            ||
// ||─────────────────────────────────────────────────────────────────────────||

enum struct weapon_t
{
	// The current amount of speed %.
	float m_flSpeed;

	// Maximum amount of speed %.
	float m_flMaxSpeed;

	// Minimum damage needed to gain a stack.
	float m_flDamageNeeded;

	// This variable gets used if "damage_needed" is greater than 0.0. 
	// If the damage dealt is lower than the minimum damage needed, it gets stored in this variable
	// and used until you've gained enough damage to gain a stack.
	float m_flDamageStorage;

	// Amount of % gained on damage.
	float m_flSpeedChange;

	// Time before you start losing your stacks after not hitting anyone for some time.
	float m_flStartDecayTime;

	// Weapon's internal instance of the delay ( last time they damaged / hit someone ).
	float m_flInternalDecayTime;

	// Amount of % you lose after not hitting anyone for some time.
	float m_flDecayAmount;

	// Function to check if the weapon has the custom attribute.
	bool HasCustomAttribute()
	{
		return !!this.m_flMaxSpeed;
	}

	// Function to get the percentage.
	float GetPercentage()
	{
		return 100.0 * (1.0 - FloatAbs(this.m_flMaxSpeed - this.m_flSpeed) / this.m_flMaxSpeed);
	}

	// Initializes all the values.
	void Init(char[] sAttribute)
	{
		this.m_flMaxSpeed          =   ReadFloatVar(sAttribute, "max",             1.0);
		this.m_flSpeedChange       =   ReadFloatVar(sAttribute, "amount",          0.05);
		this.m_flDamageNeeded      =   ReadFloatVar(sAttribute, "damage_needed",   0.0);
		this.m_flStartDecayTime    =   ReadFloatVar(sAttribute, "decay_time",      1.0);
		this.m_flDecayAmount       =   ReadFloatVar(sAttribute, "decay_amount",    0.05);
		this.m_flDamageStorage     =   0.0;
		this.m_flSpeed             =   0.0;
		this.m_flInternalDecayTime =   0.0;

		return;
	}

	// "Nullifies" all the variables.
	void Destroy()
	{
		this.m_flMaxSpeed          =   0.0;
		this.m_flSpeedChange       =   0.0;
		this.m_flDamageNeeded      =   0.0;
		this.m_flStartDecayTime    =   0.0;
		this.m_flDecayAmount       =   0.0;
		this.m_flDamageStorage     =   0.0;
		this.m_flSpeed             =   0.0;
		this.m_flInternalDecayTime =   0.0;

		return;
	}
}

weapon_t g_hWeapons[TF2_MAXPLAYERS][MAX_SLOTS];

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               SOURCEMOD API                              ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnPluginStart() 
{
	// Events
	HookEvent("post_inventory_application", Event_PostInventoryApplication);

	// Late-load support
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;

		OnClientPutInServer(iClient);
	}

	return;
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;

		int iWeapon = TF2_GetActiveWeapon(iClient);

		if(iWeapon <= 0 || !IsValidEntity(iWeapon))
			continue;

		int iSlot = TF2Util_GetWeaponSlot(iWeapon);

		if(iSlot >= sizeof(g_hWeapons[]))
			continue;

		if(!g_hWeapons[iClient][iSlot].HasCustomAttribute())
			continue;

		// If the plugin gets unloaded for some reason and someone has the attribute,
		// and let's say they have 100%, they'll keep the bonus across all the weapons.
		// Doing this to avoid it in case it happens.
		RemoveFireRate(iClient);

		ClearAttributeCache(iClient);
	}

	return;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
	SDKHook(iClient, SDKHook_PostThinkPost,         OnClientPostThinkPost);
	SDKHook(iClient, SDKHook_WeaponEquipPost,       OnWeaponEquipPost);
	SDKHook(iClient, SDKHook_WeaponSwitchPost,      OnWeaponSwitchPost);

	return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                EVENTS                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if(!IsValidClient(iClient))
		return;

	for(int iSlot = 0; iSlot < sizeof(g_hWeapons[]); iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);

		if(iWeapon <= 0 || !IsValidEntity(iWeapon))
			continue;

		char sAttribute[300];
		if(!TF2CustAttr_GetString(iWeapon, "speed increase mult on hit", sAttribute, sizeof(sAttribute)))
		{
			// Doing this in case the player had a weapon with this custom attribute before
			// switching to the current weapon.
			g_hWeapons[iClient][iSlot].Destroy();

			continue;
		}

		g_hWeapons[iClient][iSlot].Init(sAttribute);
	}

	return;	
}

public void OnWeaponEquipPost(int iClient, int iWeapon)
{
	if(!IsValidClient(iClient))
		return;

	if(iWeapon <= 0 || !IsValidEntity(iWeapon))
		return;

	int iSlot = TF2Util_GetWeaponSlot(iWeapon);

	if(iSlot >= sizeof(g_hWeapons[]))
		return;

	char sAttribute[300];
	if(!TF2CustAttr_GetString(iWeapon, "speed increase mult on hit", sAttribute, sizeof(sAttribute)))
	{
		// Doing this in case the player had a weapon with this custom attribute before
		// switching to the current weapon.
		g_hWeapons[iClient][iSlot].Destroy();

		return;
	}

	g_hWeapons[iClient][iSlot].Init(sAttribute);

	return;
}

public void OnWeaponSwitchPost(int iClient, int iWeapon)
{
	static int iLastLost[36] = {0, ...};

	if(!IsValidClient(iClient))
		return;

	if(iWeapon <= 0 || !IsValidEntity(iWeapon))
		return;

	int iSlot = TF2Util_GetWeaponSlot(iWeapon);

	int iPreviousSlot = iLastLost[iClient];

	if(iPreviousSlot == iSlot)
    	return;

	iLastLost[iClient] = iSlot;
	
	// Born to be a happy man. Forced to nest IFs. Forgive me God.
	if(iPreviousSlot < sizeof(g_hWeapons[]))
	{
		// Resetting the fire rate in case the previous weapon had bonus fire-rate.
		if(g_hWeapons[iClient][iPreviousSlot].m_flMaxSpeed && g_hWeapons[iClient][iPreviousSlot].m_flSpeed)
		{
			RemoveFireRate(iClient);

			ClearAttributeCache(iClient);
		}
	}

	if(iSlot >= sizeof(g_hWeapons[]))
		return;

	if(!g_hWeapons[iClient][iSlot].m_flMaxSpeed)
		return;

	if(!g_hWeapons[iClient][iSlot].m_flSpeed)
		return;

	// Re-applying the fire-rate to the weapon since we switched back to it.
	ModifyFireRate(iClient, iSlot);

	return;
}

public void OnTakeDamageAlivePost(int iVictim, int iAttacker, int iInflictor, float flDamage, int iDamageType, int iWeapon, const float vDamageForce[3], const float vDamagePosition[3], int iDamagecustom)
{
	if(!IsValidClient(iVictim) || !IsValidClient(iAttacker) || !IsValidEntity(iWeapon) || iAttacker == iVictim)
		return;

	if(iWeapon <= 0 || !IsValidEntity(iWeapon))
		return;

	// Sometimes iWeapon is... not a weapon.
	if(!TF2Util_IsEntityWeapon(iWeapon))
		return;

	int iSlot = TF2Util_GetWeaponSlot(iWeapon);

	if(iSlot >= sizeof(g_hWeapons[]))
		return;

	if(!g_hWeapons[iAttacker][iSlot].HasCustomAttribute())
		return;

	g_hWeapons[iAttacker][iSlot].m_flInternalDecayTime = GetGameTime() + g_hWeapons[iAttacker][iSlot].m_flStartDecayTime;

	if(IsInvuln(iVictim))
		return;

	g_hWeapons[iAttacker][iSlot].m_flDamageStorage += flDamage;

	if(g_hWeapons[iAttacker][iSlot].m_flDamageStorage < g_hWeapons[iAttacker][iSlot].m_flDamageNeeded)
		return;

	g_hWeapons[iAttacker][iSlot].m_flDamageStorage = 0.0;

	g_hWeapons[iAttacker][iSlot].m_flSpeed += g_hWeapons[iAttacker][iSlot].m_flSpeedChange;

	if(g_hWeapons[iAttacker][iSlot].m_flSpeed > g_hWeapons[iAttacker][iSlot].m_flMaxSpeed)
		g_hWeapons[iAttacker][iSlot].m_flSpeed = g_hWeapons[iAttacker][iSlot].m_flMaxSpeed;

	ModifyFireRate(iAttacker, iSlot);

	return;
}

public void OnClientPostThinkPost(int iClient) 
{
	for(int iSlot; iSlot < sizeof(g_hWeapons[]); iSlot++) 
	{
		// Since we don't have any bonus speed in the first place, there is no need to go further.
		if(!g_hWeapons[iClient][iSlot].m_flSpeed)
			continue;
		
		float flInternalDecayTime = g_hWeapons[iClient][iSlot].m_flInternalDecayTime;

		// If the weapon doesn't have any decay time ( 0.0 value in the attribute for the weapon )
		// or we haven't reached the "decay time" yet, abort.
		if(!flInternalDecayTime || flInternalDecayTime > GetGameTime())
			continue;

		g_hWeapons[iClient][iSlot].m_flSpeed -= GetGameFrameTime() * g_hWeapons[iClient][iSlot].m_flDecayAmount;

		if(g_hWeapons[iClient][iSlot].m_flSpeed < 0.0)
			g_hWeapons[iClient][iSlot].m_flSpeed = 0.0;

		int iActiveWeapon = TF2_GetActiveWeapon(iClient);

		if(iActiveWeapon <= 0)
			return;

		if(TF2Util_GetWeaponSlot(iActiveWeapon) != iSlot)
			continue;

		ModifyFireRate(iClient, iSlot);
	}

	return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               FUNCTIONS                                  ||
// ||──────────────────────────────────────────────────────────────────────────||

public void ModifyFireRate(int iClient, int iSlot)
{
	// Inverted percentage attributes! To make them "faster" you have to go below < 1.0.

	RemoveFireRate(iClient);

	TF2Attrib_AddCustomPlayerAttribute(iClient, "fire rate bonus HIDDEN",       1.0 - g_hWeapons[iClient][iSlot].m_flSpeed, -1.0);
	TF2Attrib_AddCustomPlayerAttribute(iClient, "reload time increased hidden", 1.0 - g_hWeapons[iClient][iSlot].m_flSpeed, -1.0);

	ClearAttributeCache(iClient);

	return;
}

public void RemoveFireRate(int iClient)
{
	TF2Attrib_RemoveCustomPlayerAttribute(iClient, "fire rate bonus HIDDEN");
	TF2Attrib_RemoveCustomPlayerAttribute(iClient, "reload time increased hidden");

	return;
}

// Thanks Nosoop!
public void ClearAttributeCache(int iClient) 
{
	TF2Attrib_ClearCache(iClient);

	for(int iSlot; iSlot < sizeof(g_hWeapons[]); iSlot++) 
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);

		if(!IsValidEntity(iWeapon))
			continue;

		TF2Attrib_ClearCache(iWeapon);

		UpdateWeaponResetParity(iWeapon); // fixes minigun
	}

	return;
}

public void UpdateWeaponResetParity(int iWeapon) 
{
	SetEntProp(iWeapon, Prop_Send, "m_bResetParity", !GetEntProp(iWeapon, Prop_Send, "m_bResetParity"));

	return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                   HUD                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public Action OnCustomStatusHUDUpdate(int iClient, StringMap entries)
{
	int iActiveWeapon = TF2_GetActiveWeapon(iClient);

	if(iActiveWeapon <= 0 || !IsValidEntity(iActiveWeapon))
		return Plugin_Continue;

	int iSlot = TF2Util_GetWeaponSlot(iActiveWeapon);

	if(iSlot >= sizeof(g_hWeapons[]))
		return Plugin_Continue;

	if(!g_hWeapons[iClient][iSlot].m_flMaxSpeed)
		return Plugin_Continue;

	float flPercentage = g_hWeapons[iClient][iSlot].GetPercentage();

	char sHudPerc[64];
	Format(sHudPerc, sizeof(sHudPerc), "Speed: %0.f%%", flPercentage);

	entries.SetString("1ca_attr_attackspeed_perc", sHudPerc);

	return Plugin_Changed;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                           Internal Functions                             ||
// ||──────────────────────────────────────────────────────────────────────────||

stock bool IsValidClient(int iClient)
{
    if(iClient <= 0 || iClient > MaxClients)
        return false;

    if(!IsClientInGame(iClient))
        return false;

    if(GetEntProp(iClient, Prop_Send, "m_bIsCoaching"))
        return false;
    
    return true;
}

stock int TF2_GetActiveWeapon(int iClient)
{
    return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock bool IsInvuln(int client)
{
    return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) 
        || TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) 
        || TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) 
        || TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage));
}