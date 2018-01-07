#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

int g_iWarden = -1;
bool g_bIsRebel[MAXPLAYERS+1] = false;
bool g_bIsFreeday[MAXPLAYERS+1] = false;
bool g_bIsWardenLocked = true;

public Plugin myinfo = {
     name = "[TF2] TF2Jail Boundary",
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
     // Check that the client is alive and not a bot
     if (!IsValidClient(client, false, true, false)) {
          PrintToChat(client, "[JAIL] Error: must be alive to become warden");
          return Plugin_Handled;
     }

     // Check that client is on blue
     if (TF2_GetClientTeam(client) == TFTeam_Blue) {
          PrintToChat(client, "[JAIL] Error: must be on blue team to become warden");
          return Plugin_Handled;
     }

     // Check that warden isn't locked
     if (!IsWardenLocked()) {
          PrintToChat(client, "[JAIL] Error: warden is locked");
          return Plugin_Handled;
     }

     // Check that there are no other wardens
     if (GetWarden() != -1) {
          PrintToChat(client, "[JAIL] Error: someone is already a warden");
          return Plugin_Handled;
     }
     
     SetPlayerWarden(client);

     return Plugin_Handled;
}

public Action Command_WardenRetire(int client, int args) {
     // Check that the player is currently warden
     if (!IsPlayerWarden(client)) {
          PrintToChat(client, "[JAIL] Error: you are not currently warden");a
          return Plugin_Handled;
     }

     RemovePlayerWarden(client);

     return Plugin_Handled;
}


/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     UnlockWarden();
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


/** ===========[ HOOKS ]========== **/

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
     // Check that the player is alive and not a bot
     if (IsValidClient(attacker, false, true, false)) {
          // Check that the attacker is on red and the victim is on blue
          if (TF2_GetClientTeam(attacker) == TFTeam_Red && TF2_GetClientTeam(victim) == TFTeam_Blue) {
               // Check that the player isn't already a rebel before making them one
               if (!IsPlayerRebel(attacker)) {
                    SetPlayerRebel(attacker);
               }
          }
     }
}     


/** ===========[ FUNCTIONS ]=========== **/

// Warden functions
public void LockWarden() {
     g_bIsWardenLocked = true;
}

public void UnlockWarden() {
     g_bIsWardenLocked = false;
}

public bool IsWardenLocked() {
     return g_bIsWardenLocked;
}

// Colour functions

public void ClearPlayerColour(int client) {
     SetPlayerColour(client, 255, 255, 255, 255);
}

public void SetPlayerColour(int client, int red, int green, int blue, int opacity) {
     if (IsValidClient(client, false, true, false)) {
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

public void HookPlayerDamage(client) {
     if (IsValidClient(client)) {
          SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
     }
}

// Clear role functions
public void ClearWarden() {
     SetPlayerWarden(-1);
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
     if (GetWarden() != -1) {
          SetPlayerColour(client, 0, 0, 255, 255);
     }
}

public void SetPlayerRebel(int client) {
     g_bIsRebel[client] = true;
     SetPlayerColour(client, 0, 255, 0, 255);
}

public void SetPlayerFreeday(int client) {
     g_bIsFreeday[client] = true;
     SetPlayerColour(client, 255, 0, 0, 255);
}

// Remove role functions
public void RemovePlayerWarden(int client) {
     if (IsPlayerWarden(client)) {
          SetPlayerWarden(-1);
          ClearPlayerColour(client);
     }
}

public void RemovePlayerRebel(int client) {
     g_bIsRebel[client] = false;
     ClearPlayerColour(client);
}
     
public void RemovePlayerFreeday(int client) {
     g_bIsFreeday[client] = false;
     ClearPlayerColour(client);
}

// Get role functions

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
