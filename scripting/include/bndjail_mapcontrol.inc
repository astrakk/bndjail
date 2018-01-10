#if defined _bndjail_mapcontrol_included_
  #endinput
#endif
#define _bndjail_mapcontrol_included_


/** ==========[ NATIVES ]========== **/

/**
 * Open the cells configured for the map
 */
native void BNDJail_OpenCells();

/**
 * Close the cells configured for the map
 */
native void BNDJail_CloseCells();

/**
 * Get the number of cell doors detected in the current round
 *
 * @return          number of cell doors detected in the current round
 */
native int BNDJail_GetDoorCount();


/** ==========[ FORWARDS ]========== **/

/**
 * Called when the cell doors are opened
 */
forward void BNDJail_OnOpenCells();

/**
 * Called when the cell doors are closed
 */
forward void BNDJail_OnCloseCells(int client);


/** ==========[ DEPENDENCY ]========== **/

#if !defined REQUIRE_PLUGIN
public void __pl_bndjail_SetNTVOptional() {
     MarkNativeAsOptional("BNDJail_OpenCells");
     MarkNativeAsOptional("BNDJail_CloseCells");

     MarkNativeAsOptional("BNDJail_GetDoorCount");
}
#endif

public SharedPlugin __pl_bndjail_mapcontrol = {
     name = "bndjail_mapcontrol",
     file = "bndjail_mapcontrol.smx",
#if defined REQUIRE_PLUGIN
     required = 1,
#else
     required = 0,
#endif
};
