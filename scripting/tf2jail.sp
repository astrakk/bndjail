#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

int g_iWarden = -1;
bool g_bIsRebel[MAXPLAYERS+1] = false;
bool g_bIsFreeday[MAXPLAYERS+1] = false;

public Plugin myinfo = {
     name = "[TF2] TF2Jail Boundary",
     author = "Astrak",
     description = "Custom TF2Jail plugin for Boudnary Servers",
     version = "1.0",
     url = "https://github.com/astrakk/"
};

public void OnPluginStart() {
     // Events
     HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
     HookEvent("player_connect", Event_PlayerConnection, EventHookMode_Pre);
     HookEvent("player_disconnect", Event_PlayerConnection, EventHookMode_Pre);

     // Hook all player damage
     for (int i = 0; i < MaxClients; i++) {
          HookPlayerDamage(i);
     }
}


/** ===========[ FORWARDS ]========== **/

public void OnClientPutInServer(int client) {
     HookPlayerDamage(client);
}


/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     ClearWarden();
     ClearRebels();
     ClearFreedays();
}

public Action Event_PlayerConnection(Event event, const char[] name, bool dontBroadcast) {
     int client = GetClientOfUserId(event.GetInt("userid"));

     RemovePlayerWarden(client);
     RemovePlayerRebel(client);
     RemovePlayerFreeday(client);
}


/** ===========[ HOOKS ]========== **/

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
     // Check that the attacker is actually a player before proceeding
     if (IsValidClient(attacker)) {

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
}

public void SetPlayerRebel(int client) {
     g_bIsRebel[client] = true;
}

public void SetPlayerFreeday(int client) {
     g_bIsFreeday[client] = true;
}

// Remove role functions
public void RemovePlayerWarden(int client) {
     if (IsPlayerWarden(client)) {
          SetPlayerWarden(-1);
     }
}

public void RemovePlayerRebel(int client) {
     g_bIsRebel[client] = false;
}
     
public void RemovePlayerFreeday(int client) {
     g_bIsFreeday[client] = false;
}

// Get role functions
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
