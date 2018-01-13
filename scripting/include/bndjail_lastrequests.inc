#if defined _bndjail_lastrequests_included_
  #endinput
#endif
#define _bndjail_lastrequests_included_


/** ==========[ NATIVES ]========== **/

/**
 * Retrieve the description of the current day's LR
 *
 * @return          true if success, false otherwise
 */
native bool BNDJail_GetLastRequestDescription(char[] description, int maxlen);


/** ==========[ DEPENDENCY ]========== **/

#if !defined REQUIRE_PLUGIN
public void __pl_bndjail_lastrequests_SetNTVOptional() {
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
