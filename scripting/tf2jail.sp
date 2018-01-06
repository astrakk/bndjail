#include <sourcemod>

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
     HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
}


/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     ClearWarden;
     ClearRebels;
     ClearFreedays;
}


/** ===========[ FUNCTIONS ]=========== **/

public void ClearWarden() {
     SetPlayerWarden(-1);
}

public void ClearRebels() {
     for (int i = 0; i < MaxClients; i++) {
          SetPlayerRebel(i, false);
     }
}

public void ClearFreedays() {
     for (int i = 0; i < MaxClients; i++) {
          SetPlayerFreeday(i, false);
     }
}

public void SetPlayerWarden(int client) {
     g_iWarden = client;
}

public void SetPlayerRebel(int client, bool status) {
     g_bIsRebel = status;
}

public void SetPlayerFreeday(int client, bool status) {
     g_IsFreeday = status;
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
	if(	!(1 <= client <= MaxClients) || 			/* Is the client a player? */
		(!IsClientInGame(client)) ||				/* Is the client in-game? */
		(IsPlayerAlive(client) && !bAllowAlive) || 	/* Is the client allowed to be alive? */
		(!IsPlayerAlive(client) && !bAllowDead) || 	/* Is the client allowed to be dead? */
		(IsFakeClient(client) && !bAllowBots)) {	/* Is the client allowed to be a bot? */
			return false;
	}
	return true;	
}
