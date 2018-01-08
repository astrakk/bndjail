#if defined _bndjail_included_
  #endinput
#endif
#define _bndjail_included_


/** ==========[ NATIVES ]========== **/

/**
 * Returns whether or not a warden is currently active.
 *
 * @return          true if the warden is active, false otherwise
 */
native bool BNDJail_IsWardenActive();

/**
 * Retrieves the client index of the current warden.
 *
 * @return          the client index of the current active warden (-1 if not active)
 */
native int BNDJail_GetWarden();

/**
 * Returns whether or not a specified client is currently the warden
 *
 * @param client    the client index to be checked
 * @return          true if the provided client index is currently the warden, false otherwise
 */
native bool BNDJail_IsPlayerWarden(int client);

/**
 * Makes a player the warden (regardless of team)
 *
 * @param client    the client index to become warden
 */
native void BNDJail_SetPlayerWarden(int client);

/**
 * Removes a player's warden status if they are currently warden
 *
 * @param client    the client index to remove warden
 */
native void BNDJail_RemovePlayerWarden(int client);

/**
 * Clears the current warden
 */
native void BNDJail_ClearWarden();


/**
 * Returns whether or not a specified client is currently a rebel
 *
 * @param client    the client index to be checked
 * @return          true if the provided client index is currently a rebel, false otherwise
 */
native bool BNDJail_IsPlayerRebel(int client);

/**
 * Makes a player the rebel (regardless of team)
 *
 * @param client    the client index to become a rebel
 */
native void BNDJail_SetPlayerRebel(int client);

/**
 * Removes a player's rebel status
 *
 * @param client    the client index to remove rebel status
 */
native void BNDJail_RemovePlayerRebel(int client);

/**
 * Removes all rebel statuses from players
 */
native void BNDJail_ClearRebels();


/**
 * Returns whether or not a specified client is currently a freeday
 *
 * @param client    the client index to be checked
 * @return          true if the provided client index is currently a freeday, false otherwise
 */
native bool BNDJail_IsPlayerFreeday(int client);

/**
 * Makes a player the freeday (regardless of team)
 *
 * @param client    the client index to become a freeday
 */
native void BNDJail_SetPlayerFreeday(int client);

/**
 * Removes a player's freeday status
 *
 * @param client    the client index to remove freeday status
 */
native void BNDJail_RemovePlayerFreeday(int client);

/**
 * Removes all freeday statuses from players
 */
native void BNDJail_ClearFreedays();
