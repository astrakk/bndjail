#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <bndjail>

#pragma semicolon 1
#pragma newdecls required

// Global variables and arrays
int g_iWarden = -1;
bool g_bIsRebel[MAXPLAYERS+1] = false;
bool g_bIsFreeday[MAXPLAYERS+1] = false;
bool g_bIsWardenLocked = true;

// Forward handles
Handle g_hOnSetPlayerWarden;
Handle g_hOnRemovePlayerWarden;
Handle g_hOnSetPlayerRebel;
Handle g_hOnRemovePlayerRebel;
Handle g_hOnSetPlayerFreeday;
Handle g_hOnRemovePlayerFreeday;
Handle g_hOnWardenLocked;
Handle g_hOnWardenUnlocked;

public Plugin myinfo = {
     name = "[TF2] BND Jailbreak",
     author = "Astrak",
     description = "Custom TF2Jail plugin for Boudnary Servers",
     version = "1.0",
     url = "https://github.com/astrakk/"
};


/** ===========[ FORWARDS ]========== **/

public void OnPluginStart() {
     // Events
     HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Pre);
     HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
     HookEvent("player_connect", Event_PlayerConnection, EventHookMode_Pre);
     HookEvent("player_disconnect", Event_PlayerConnection, EventHookMode_Pre);
     HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
     HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
     HookEvent("post_inventory_application", Event_PlayerSpawn, EventHookMode_Post);

     // Hook all player damage
     for (int i = 0; i < MaxClients; i++) {
          HookPlayerDamage(i);
     }

     // Public commands
     RegConsoleCmd("sm_w", Command_WardenVolunteer, "Volunteer to become the warden when on blue team");
     RegConsoleCmd("sm_warden", Command_WardenVolunteer, "Volunteer to become the warden when on blue team");
     RegConsoleCmd("sm_uw", Command_WardenRetire, "Retire as warden to become a regular guard");
     RegConsoleCmd("sm_unwarden", Command_WardenRetire, "Retire as warden to become a regular guard");

     // Admin commands
     RegConsoleCmd("sm_forcewarden", Admin_ForceWarden, "Force a player to be warden if they are on blue");
     RegConsoleCmd("sm_removewarden", Admin_RemoveWarden, "Force the current warden to retire");
     RegConsoleCmd("sm_forcefreeday", Admin_ForceFreeday, "Force a player to become a freeday");
     RegConsoleCmd("sm_removefreeday", Admin_RemoveFreeday, "Force a player to lose their freeday status");

     // Translations
     LoadTranslations("common.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
     // Dependency
     RegPluginLibrary("bndjail");

     // Natives
     CreateNative("BNDJail_IsWardenActive", Native_IsWardenActive);
     CreateNative("BNDJail_GetWarden", Native_GetWarden);
     CreateNative("BNDJail_IsPlayerWarden", Native_IsPlayerWarden);
     CreateNative("BNDJail_SetPlayerWarden", Native_SetPlayerWarden);
     CreateNative("BNDJail_RemovePlayerWarden", Native_RemovePlayerWarden);
     CreateNative("BNDJail_ClearWarden", Native_ClearWarden);

     CreateNative("BNDJail_IsPlayerRebel", Native_IsPlayerRebel);
     CreateNative("BNDJail_SetPlayerRebel", Native_SetPlayerRebel);
     CreateNative("BNDJail_RemovePlayerRebel", Native_RemovePlayerRebel);
     CreateNative("BNDJail_ClearRebels", Native_ClearRebels);

     CreateNative("BNDJail_IsPlayerFreeday", Native_IsPlayerFreeday);
     CreateNative("BNDJail_SetPlayerFreeday", Native_SetPlayerFreeday);
     CreateNative("BNDJail_RemovePlayerFreeday", Native_RemovePlayerFreeday);
     CreateNative("BNDJail_ClearFreedays", Native_ClearFreedays);

     CreateNative("BNDJail_IsWardenLocked", Native_IsWardenLocked);
     CreateNative("BNDJail_LockWarden", Native_LockWarden);
     CreateNative("BNDJail_UnlockWarden", Native_UnlockWarden);

     // Forwards
     g_hOnSetPlayerWarden = CreateGlobalForward("BNDJail_OnSetPlayerWarden", ET_Event, Param_Cell);
     g_hOnRemovePlayerWarden = CreateGlobalForward("BNDJail_OnRemovePlayerWarden", ET_Event, Param_Cell);

     g_hOnSetPlayerRebel = CreateGlobalForward("BNDJail_OnSetPlayerRebel", ET_Event, Param_Cell);
     g_hOnRemovePlayerRebel = CreateGlobalForward("BNDJail_OnRemovePlayerRebel", ET_Event, Param_Cell);

     g_hOnSetPlayerFreeday = CreateGlobalForward("BNDJail_OnSetPlayerFreeday", ET_Event, Param_Cell);
     g_hOnRemovePlayerFreeday = CreateGlobalForward("BNDJail_OnRemovePlayerFreeday", ET_Event, Param_Cell);

     g_hOnWardenLocked = CreateGlobalForward("BNDJail_OnWardenLocked", ET_Event, Param_Cell);
     g_hOnWardenUnlocked = CreateGlobalForward("BNDJail_OnWardenUnlocked", ET_Event, Param_Cell);

     return APLRes_Success;
}

public void OnClientPutInServer(int client) {
     HookPlayerDamage(client);
}

public void OnEntityCreated(int entity, const char[] classname) {
     if (StrEqual(classname, "tf_dropped_weapon") || StrEqual(classname, "tf_ammo_pack")) {
          AcceptEntityInput(entity, "kill");
     }
}


/** ===========[ COMMANDS ]========== **/

public Action Command_WardenVolunteer(int client, int args) {
     // Check that the client is alive
     if (!IsValidClient(client, false, true, true)) {
          PrintToChat(client, "[JAIL] Error: must be alive to become warden");
          return Plugin_Handled;
     }

     // Check that client is on blue
     if (TF2_GetClientTeam(client) != TFTeam_Blue) {
          PrintToChat(client, "[JAIL] Error: must be on blue team to become warden");
          return Plugin_Handled;
     }

     // Check that warden isn't locked
     if (IsWardenLocked()) {
          PrintToChat(client, "[JAIL] Error: warden is locked");
          return Plugin_Handled;
     }

     // Check that there are no other wardens
     if (IsWardenActive()) {
          PrintToChat(client, "[JAIL] Error: someone is already a warden");
          return Plugin_Handled;
     }
     
     SetPlayerWarden(client);

     return Plugin_Handled;
}

public Action Command_WardenRetire(int client, int args) {
     // Check that the player is currently warden
     if (!IsPlayerWarden(client)) {
          PrintToChat(client, "[JAIL] Error: you are not currently warden");
          return Plugin_Handled;
     }

     RemovePlayerWarden(client);

     return Plugin_Handled;
}


public Action Admin_ForceWarden(int client, int args) {
     // Check that there is at least 1 argument
     if (args < 1) {
          return Plugin_Handled;
     }

     // Retrieve the target name
     char arg[MAX_NAME_LENGTH];
     GetCmdArgString(arg, sizeof(arg));

     // Find the target
     int target = FindTarget(client, arg);

     // Target not found
     if (target == -1) {
          return Plugin_Handled;
     }

     // Target not alive
     if (!IsValidClient(target, false, true, true)) {
          return Plugin_Handled;
     }

     // Target not on blue team
     if (TF2_GetClientTeam(target) != TFTeam_Blue) {
          return Plugin_Handled;
     }

     // Target is already warden
     if (IsPlayerWarden(target)) {
          return Plugin_Handled;
     }

     SetPlayerWarden(target);
     return Plugin_Handled;
}

public Action Admin_RemoveWarden(int client, int args) {
     // Check that there is at least 1 argument
     if (args < 1) {
          return Plugin_Handled;
     }

     // Retrieve the target name
     char arg[MAX_NAME_LENGTH];
     GetCmdArgString(arg, sizeof(arg));

     // Find the target
     int target = FindTarget(client, arg);

     // Target not found
     if (target == -1) {
          return Plugin_Handled;
     }

     // Target not warden
     if (!IsPlayerWarden(target)) {
          return Plugin_Handled;
     }

     RemovePlayerWarden(target);
     return Plugin_Handled;
}

public Action Admin_ForceFreeday(int client, int args) {
     // Check that there is at least 1 argument
     if (args < 1) {
          return Plugin_Handled;
     }

     // Retrieve the target name
     char arg[MAX_NAME_LENGTH];
     GetCmdArgString(arg, sizeof(arg));

     // Find the target
     int target = FindTarget(client, arg);

     // Target not found
     if (target == -1) {
          return Plugin_Handled;
     }

     // Target not alive
     if (!IsValidClient(target, false, true, true)) {
          return Plugin_Handled;
     }

     // Target not on red team
     if (TF2_GetClientTeam(target) != TFTeam_Red) {
          return Plugin_Handled;
     }

     // Target already freeday
     if (IsPlayerFreeday(target)) {
          return Plugin_Handled;
     }

     SetPlayerFreeday(target);
     return Plugin_Handled;
}

public Action Admin_RemoveFreeday(int client, int args) {
     // Check that there is at least 1 argument
     if (args < 1) {
          return Plugin_Handled;
     }

     // Retrieve the target name
     char arg[MAX_NAME_LENGTH];
     GetCmdArgString(arg, sizeof(arg));

     // Find the target
     int target = FindTarget(client, arg);

     // Target not found
     if (target == -1) {
          return Plugin_Handled;
     }

     // Target not freeday
     if (!IsPlayerFreeday(target)) {
          return Plugin_Handled;
     }

     RemovePlayerFreeday(target);
     return Plugin_Handled;
}

/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     UnlockWarden();
     BalanceTeams();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
     ClearWarden();
     ClearRebels();
     ClearFreedays();
     LockWarden();
}

public Action Event_PlayerConnection(Event event, const char[] name, bool dontBroadcast) {
     int client = GetClientOfUserId(event.GetInt("userid"));

     RemovePlayerWarden(client);
     RemovePlayerRebel(client);
     RemovePlayerFreeday(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
     int client = GetClientOfUserId(event.GetInt("userid"));

     if (TF2_GetClientTeam(client) == TFTeam_Red) {
          ClearPlayerWeapons(client);
     }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
     int client = GetClientOfUserId(event.GetInt("userid"));

     RemovePlayerWarden(client);
     RemovePlayerRebel(client);
     RemovePlayerFreeday(client);
}


/** ===========[ HOOKS ]========== **/

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
     // Check that the player is alive (ensures world damage doesn't count)
     if (IsValidClient(attacker, false, true, true)) {
          // If the victim is a freeday and the attacker isn't the warden, block damage
          if (IsPlayerFreeday(victim) && !IsPlayerWarden(attacker)) {
               return Plugin_Handled;
          }

          // If the attacker is a freeday, remove their freeday status
          if (IsPlayerFreeday(attacker)) {
               RemovePlayerFreeday(attacker);
          }

          // If the attacker is a red non-rebel and the victim is on blue, mark the red as a rebel
          if (TF2_GetClientTeam(attacker) == TFTeam_Red && TF2_GetClientTeam(victim) == TFTeam_Blue) {
               if (!IsPlayerRebel(attacker)) {
                    SetPlayerRebel(attacker);
               }
          }
     }

     return Plugin_Continue;
}     


/** ===========[ FUNCTIONS ]=========== **/

// Balance team functions
public void BalanceTeams() {
     for (int i = 0; i < MaxClients; i++) {
          // Check if the ratio is above 2 reds to 1 blue
          if (float(GetTeamPlayerCount(TFTeam_Blue))/float(GetTeamPlayerCount(TFTeam_Red)) > 0.5) {
               // Balance the players on blue team if the ratio is off
               if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue) {
                    TF2_ChangeClientTeam(i, TFTeam_Red);
                    TF2_RespawnPlayer(i);
               }
          }
     }
}

public int GetTeamPlayerCount(TFTeam tfteam) {
     // Convert TFTeam values into team indexes
     switch (tfteam) {
          case TFTeam_Spectator: {
               return GetTeamClientCount(1);
          }
          case TFTeam_Red: {
               return GetTeamClientCount(2);
          }
          case TFTeam_Blue: {
               return GetTeamClientCount(3);
          }
     }

     return 0;
}

// Warden functions
public void LockWarden() {
     g_bIsWardenLocked = true;

     Call_StartForward(g_hOnWardenLocked);
     Call_Finish();
}

public void UnlockWarden() {
     g_bIsWardenLocked = false;

     Call_StartForward(g_hOnWardenUnlocked);
     Call_Finish();
}

public bool IsWardenLocked() {
     return g_bIsWardenLocked;
}

// Colour functions

public void ClearPlayerColour(int client) {
     SetPlayerColour(client, 255, 255, 255, 255);
}

public void SetPlayerColour(int client, int red, int green, int blue, int opacity) {
     if (IsValidClient(client, false, true, true)) {
          SetEntityRenderColor(client, red, green, blue, opacity);
     }
}

// Weapon functions
public void ClearPlayerWeapons(int client) {
     // Remove different slots depending on the class of the player
     switch (TF2_GetPlayerClass(client)) {
          case TFClass_Scout: {
               RemovePlayerWeapon(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Soldier: {
               RemovePlayerWeapon(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Pyro: {
               RemovePlayerWeapon(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_DemoMan: {
               RemovePlayerWeapon(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Heavy: {
               RemovePlayerAmmo(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Engineer: {
               RemovePlayerWeapon(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Medic: {
               RemovePlayerWeapon(client, 0);
          }
          case TFClass_Sniper: {
               RemovePlayerAmmo(client, 0);
               RemovePlayerWeapon(client, 1);
          }
          case TFClass_Spy: {
               RemovePlayerWeapon(client, 0);
          }
     }
}

public void RemovePlayerWeapon(int client, int slot) {
     RemovePlayerClip(client, slot);
     RemovePlayerAmmo(client, slot);
}

public void RemovePlayerClip(int client, int slot) {
     int iWeapon = GetPlayerWeaponSlot(client, slot);

     // Check that the slot actually contains a weapon before proceeding
     if (IsValidEntity(iWeapon)) {
          SetEntProp(iWeapon, Prop_Send, "m_iClip1", 0);
     }
}

public void RemovePlayerAmmo(int client, int slot) {
     int iWeapon = GetPlayerWeaponSlot(client, slot);

     // Check that the slot actually contains a weapon before proceeding
     if (IsValidEntity(iWeapon)) {
          int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
          SetEntProp(client, Prop_Data, "m_iAmmo", 0, _, iAmmoType);
     }
}

public void HookPlayerDamage(int client) {
     if (IsValidClient(client)) {
          SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
     }
}

// Clear role functions
public void ClearWarden() {
     RemovePlayerWarden(GetWarden());
}

public void ClearRebels() {
     for (int i = 0; i < MaxClients; i++) {
          RemovePlayerRebel(i);
     }
}

public void ClearFreedays() {
     for (int i = 0; i < MaxClients; i++) {
          RemovePlayerFreeday(i);
     }
}

// Set role functions
public void SetPlayerWarden(int client) {
     g_iWarden = client;
     
     // Only set the player colour if warden is not unset
     if (IsWardenActive()) {
          SetPlayerColour(client, 0, 0, 255, 255);
     }

     Call_StartForward(g_hOnSetPlayerWarden);
     Call_PushCell(client);
     Call_Finish();
}

public void SetPlayerRebel(int client) {
     g_bIsRebel[client] = true;
     SetPlayerColour(client, 0, 255, 0, 255);

     Call_StartForward(g_hOnSetPlayerRebel);
     Call_PushCell(client);
     Call_Finish();
}

public void SetPlayerFreeday(int client) {
     g_bIsFreeday[client] = true;
     SetPlayerColour(client, 255, 0, 0, 255);

     Call_StartForward(g_hOnSetPlayerFreeday);
     Call_PushCell(client);
     Call_Finish();
}

// Remove role functions
public void RemovePlayerWarden(int client) {
     if (IsPlayerWarden(client)) {
          SetPlayerWarden(-1);
          ClearPlayerColour(client);

          Call_StartForward(g_hOnRemovePlayerWarden);
          Call_PushCell(client);
          Call_Finish();
     }
}

public void RemovePlayerRebel(int client) {
     g_bIsRebel[client] = false;
     ClearPlayerColour(client);

     Call_StartForward(g_hOnRemovePlayerRebel);
     Call_PushCell(client);
     Call_Finish();
}
     
public void RemovePlayerFreeday(int client) {
     g_bIsFreeday[client] = false;
     ClearPlayerColour(client);

     Call_StartForward(g_hOnRemovePlayerFreeday);
     Call_PushCell(client);
     Call_Finish();
}

// Get role functions

public bool IsWardenActive() {
     if (GetWarden() != -1) {
          return true;
     }

     return false;
}

public int GetWarden() {
     return g_iWarden;
}

public bool IsPlayerWarden(int client) {
     if (client == g_iWarden) {
          return true;
     }

     return false;
}

public bool IsPlayerRebel(int client) {
     return g_bIsRebel[client];
}

public bool IsPlayerFreeday(int client) {
     return g_bIsFreeday[client];
}

bool IsValidClient(int client, bool bAllowDead = true, bool bAllowAlive = true, bool bAllowBots = true) {
     if(  !(1 <= client <= MaxClients) ||              /* Is the client a player? */
          (!IsClientInGame(client)) ||                 /* Is the client in-game? */
          (IsPlayerAlive(client) && !bAllowAlive) ||   /* Is the client allowed to be alive? */
          (!IsPlayerAlive(client) && !bAllowDead) ||   /* Is the client allowed to be dead? */
          (IsFakeClient(client) && !bAllowBots)) {     /* Is the client allowed to be a bot? */
               return false;
     }
     return true;   
}


/** ==========[ NATIVES ]========== **/

public int Native_IsWardenActive(Handle plugin, int numParams) {
     return IsWardenActive();
}

public int Native_GetWarden(Handle plugin, int numParams) {
     return GetWarden();
}

public int Native_IsPlayerWarden(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     return IsPlayerWarden(client);
}

public int Native_SetPlayerWarden(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     SetPlayerWarden(client);
}

public int Native_RemovePlayerWarden(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     RemovePlayerWarden(client);
}

public int Native_ClearWarden(Handle plugin, int numParams) {
     ClearWarden();
}


public int Native_IsPlayerRebel(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     return IsPlayerRebel(client);
}

public int Native_SetPlayerRebel(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     SetPlayerRebel(client);
}

public int Native_RemovePlayerRebel(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     RemovePlayerRebel(client);
}

public int Native_ClearRebels(Handle plugin, int numParams) {
     ClearRebels();
}


public int Native_IsPlayerFreeday(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     return IsPlayerFreeday(client);
}

public int Native_SetPlayerFreeday(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     SetPlayerFreeday(client);
}

public int Native_RemovePlayerFreeday(Handle plugin, int numParams) {
     int client = GetNativeCell(1);

     RemovePlayerFreeday(client);
}

public int Native_ClearFreedays(Handle plugin, int numParams) {
     ClearFreedays();
}


public int Native_IsWardenLocked(Handle plugin, int numParams) {
     return IsWardenLocked();
}

public int Native_LockWarden(Handle plugin, int numParams) {
     LockWarden();
}

public int Native_UnlockWarden(Handle plugin, int numParams) {
     UnlockWarden();
}
