#if defined _bndjail_lastrequests_included_
  #endinput
#endif
#define _bndjail_lastrequests_included_


/** ==========[ NATIVES ]========== **/

/**
 * Returns whether or not last request is locked (cannot give or select new last requests)
 *
 * @return          true if locked, false otherwise
 */
native bool BNDJail_IsLastRequestLocked();

/**
 * Returns whether or not the a player has already been given a last request (does not mean one has been selected though)
 *
 * @return          true if a player has been given their last request, false otherwise
 */
native bool BNDJail_IsLastRequestGiven();

/**
 * Returns whether or not the a player has already been given a last request (does not mean one has been selected though)
 *
 * @return          true if a player has selected a last request this round, false otherwise
 */
native bool BNDJail_IsLastRequestSelected();

/**
* Returns whether or not the current round is a last request round (anytime after previous round end counts as next day)
 *
 * @return          true if last request round is playing out this round, false otherwise
 */
native bool BNDJail_IsTodayLastRequest();

/**
 * Returns whether or not the next round is a last request round (as soon as the round ends it will be considered the next round)
 *
 * @return          true if last request round is being played tomorrow, false otherwise
 */
native bool BNDJail_IsTomorrowLastRequest();

/**
 * Retrieve the client who chose the current day's LR
 *
 * @return          client index on success, -1 if no LR
 */
native int BNDJail_GetCurrentLastRequestClient();

/**
 * Retrieve the handler of the current day's LR
 *
 * @return          true if success, false otherwise
 */
native bool BNDJail_GetCurrentLastRequestHandler(char[] handler, int maxlen);

/**
 * Retrieve the description of the provided LR handler
 *
 * @return          true if success, false otherwise
 */
native bool BNDJail_GetLastRequestDescription(const char[] handler, char[] description, int maxlen);


/** ==========[ FORWARDS ]========== **/

/**
 * Called just before a last request is executed
 */
forward void BNDJail_OnExecuteLastRequest(int client, const char[] handler);

/**
 * Called just before a last request is cleaned
 */
forward void BNDJail_OnCleanLastRequest(int client, const char[] handler);

/**
 * Called after last request has been given to a player
 */
forward void BNDJail_OnGiveLastRequest(int client);

/**
 * Called after a last request is selected by a player
 */
forward void BNDJail_OnSelectLastRequest(int client, const char[] handler);

/**
 * Called when the last request menu is closed before selecting the next rounds last request
 */
forward void BNDJail_OnCancelLastRequest(int client);


/** ==========[ DEPENDENCY ]========== **/

#if !defined REQUIRE_PLUGIN
public void __pl_bndjail_lastrequests_SetNTVOptional() {
     MarkNativeAsOptional("BNDJail_IsLastRequestLocked");
     MarkNativeAsOptional("BNDJail_IsLastRequestGiven");
     MarkNativeAsOptional("BNDJail_IsLastRequestSelected");
     MarkNativeAsOptional("BNDJail_IsTodayLastRequest");
     MarkNativeAsOptional("BNDJail_IsTomorrowLastRequest");
     MarkNativeAsOptional("BNDJail_GetCurrentLastRequestClient");
     MarkNativeAsOptional("BNDJail_GetCurrentLastRequestHandler");
     MarkNativeAsOptional("BNDJail_GetLastRequestDescription");
}
#endif

public SharedPlugin __pl_bndjail_lastrequests = {
     name = "bndjail_lastrequests",
     file = "bndjail_lastrequests.smx",
#if defined REQUIRE_PLUGIN
     required = 1,
#else
     required = 0,
#endif
};
