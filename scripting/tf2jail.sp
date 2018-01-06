#include <sourcemod>

public Plugin myinfo = {
	name = "[TF2] TF2Jail Boundary",
	author = "Astrak",
	description = "Custom TF2Jail plugin for Boudnary Servers",
	version = "1.0",
	url = "https://github.com/astrakk/"
};

public void OnPluginStart() {

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
