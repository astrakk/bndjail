#include <sourcemod>
#include <bndjail>
#include <bndjail_lastrequests>

// Global variables and arrays
Handle g_hWardenText;
Handle g_hLastRequestText;

public Plugin myinfo = {
	name = "[TF2] BNDJail Heads Up Display",
	author = "Astrak",
	description = "Heads Up Display module for BNDJail ",
	version = "1.0",
	url = "https://github.com/astrakk/bndjail"
};


/** ==========[ FORWARDS ]========== **/

public void OnPluginStart() {
     // Events
     HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);

     // HUD
     g_hWardenText = CreateHudSynchronizer();
     g_hLastRequestText = CreateHudSynchronizer();
}

public void OnPluginEnd() {
     ClearHuds();
}

public void BNDJail_OnSetPlayerWarden(int client) {
     SetWardenHud(client);
}

public void BNDJail_OnRemovePlayerWarden(int client) {
     ClearWardenHud();
}

public void BNDJail_OnExecuteLastRequest(int client, const char[] handler) {
     char description[255];

     // Retrieve the description of the current LR handler
     bool result = BNDJail_GetLastRequestDescription(handler, description, sizeof(description));

     if (result) {
          SetLastRequestHud(description);
     }
}


/** ==========[ EVENTS ]========== **/

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
     ClearHuds();
}


/** ==========[ FUNCTIONS ]========== **/

public void ClearHuds() {
     ClearWardenHud();
     ClearLastRequestHud();
}

public void SetWardenHud(int client) {
     // Set the warden text to appear in the top left and white
     SetHudTextParams(0.05, 0.13, 1209600.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
     for (int i = 1; i < MaxClients; i++) {
          if (IsValidClient(i, true, true, false)) {
               ShowSyncHudText(i, g_hWardenText, "Warden: %N", client);
          }
     }
}

public void ClearWardenHud() {
     for (int i = 0; i < MaxClients; i ++) {
          if (IsValidClient(i, true, true, false)) {
               ClearSyncHud(i, g_hWardenText);
          }
     }
}

public void SetLastRequestHud(const char[] description) {
     // Trim the LR description text to 100 chars to fit on screen properly
     char cShortenedText[100];
     strcopy(cShortenedText, sizeof(cShortenedText), description);

     // Set the LR description text to appear in the top left and red
     SetHudTextParams(0.05, 0.18, 1209600.0, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
     for (int i = 1; i < MaxClients; i++) {
          if (IsValidClient(i, true, true, false)) {
               ShowSyncHudText(i, g_hLastRequestText, "Last Request: %s", cShortenedText);
          }
     }
}

public void ClearLastRequestHud() {
     for (int i = 0; i < MaxClients; i ++) {
          if (IsValidClient(i, true, true, false)) {
               ClearSyncHud(i, g_hLastRequestText);
          }
     }
}

/**
 * Checks that a player meets a specified set of conditions
 *
 * @param client         the client to be checked
 * @param bAllowDead     whether or not the client is allowed to be dead (default: true)
 * @param bAllowAlive    whether or not the client is allowed to be alive (default: true)
 * @param bAllowBots     whether or not the client is allowed to be a bot (default: true)
 * @return               true if the client meets all specified conditions, otherwise false
 */
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
