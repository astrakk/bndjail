#include <sourcemod>
#include <sdktools>

#include <bndjail>
#include <bndjail_mapcontrol>

#pragma semicolon 1
#pragma newdecls required

// Global variables and arrays
ArrayList g_iDoorEntityList;
ArrayList g_iDoorButtonEntityList;
ArrayList g_iFFButtonEntityList;

char g_cDoorEntityName[64];
char g_cDoorButtonEntityName[64];
char g_cFFButtonEntityName[64];

// Forward handles
Handle g_hOnOpenCells;
Handle g_hOnCloseCells;

public Plugin myinfo = {
     name = "[TF2] BNDJail Map Control",
     author = "Astrak",
     description = "Map Control module for BNDJail",
     version = "1.0",
     url = "https://github.com/astrakk/"
};


/** ===========[ FORWARDS ]========== **/

public void OnPluginStart() {
     // Events
     HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre); // using teamplay_round_start to run before players can move

     // Public commands
     RegConsoleCmd("sm_open", Command_OpenCells, "Open the cell doors as warden");
     RegConsoleCmd("sm_close", Command_OpenCells, "Close the cell doors as warden");

     // Admin commands
     RegAdminCmd("sm_forceopen", Admin_OpenCells, 6, "Open the cell doors as an admin");
     RegAdminCmd("sm_forceclose", Admin_CloseCells, 6, "Close the cell doors as an admin");

     // Translations
     LoadTranslations("common.phrases");

     // Read map config
     LoadConfig("/addons/sourcemod/configs/bndjail/bndjail_mapcontrol.cfg");
}

public void OnMapStart() {
     // Read map config
     LoadConfig("/addons/sourcemod/configs/bndjail/bndjail_mapcontrol.cfg");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
     // Dependency
     RegPluginLibrary("bndjail_mapcontrol");

     // Natives
     CreateNative("BNDJail_OpenCells", Native_OpenCells);
     CreateNative("BNDJail_CloseCells", Native_CloseCells);

     // Forwards
     g_hOnOpenCells = CreateGlobalForward("BNDJail_OnOpenCells", ET_Event, Param_Cell);
     g_hOnCloseCells = CreateGlobalForward("BNDJail_OnCloseCells", ET_Event, Param_Cell);

     return APLRes_Success;
}


/** ===========[ COMMANDS ]========== **/

// Public commands
public Action Command_OpenCells(int client, int args) {
     // Player not warden
     if (!BNDJail_IsPlayerWarden(client)) {
          return Plugin_Handled;
     }

     OpenCells();

     return Plugin_Handled;
}

public Action Command_CloseCells(int client, int args) {
     // Player not warden
     if (!BNDJail_IsPlayerWarden(client)) {
          return Plugin_Handled;
     }

     CloseCells();

     return Plugin_Handled;
}


// Admin commands
public Action Admin_OpenCells(int client, int args) {
     // Open the cells if the player is an admin
     OpenCells();

     Call_StartForward(g_hOnOpenCells);
     Call_Finish();

     return Plugin_Handled;
}

public Action Admin_CloseCells(int client, int args) {
     // Close the cells if the player is an admin
     CloseCells();

     Call_StartForward(g_hOnCloseCells);
     Call_Finish();

     return Plugin_Handled;
}


/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     UpdateEntityLists();
}


/** ===========[ FUNCTIONS ]=========== **/

// Door control functions
public void OpenCells() {
     for (int i = 0; i < GetArraySize(g_iDoorEntityList); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorEntityList, i), "Open");
     }
}

public void CloseCells() {
     for (int i = 0; i < GetArraySize(g_iDoorEntityList); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorEntityList, i), "Close");
     }
}

// Config functions
public bool LoadConfig(const char[] config) {
     KeyValues kv = new KeyValues("Maps");

     // Could not read from file
     if (!FileToKeyValues(kv, config)) {
          CloseHandle(kv);
          return false;
     }

     // Could not find current map in config
     char map[PLATFORM_MAX_PATH];
     GetCurrentMap(map, sizeof(map));

     if (!KvJumpToKey(kv, map, false)) {
          CloseHandle(kv);
          return false;
     }

     KvGetString(kv, "door_name", g_cDoorEntityName, sizeof(g_cDoorEntityName));
     KvGetString(kv, "door_button", g_cDoorButtonEntityName, sizeof(g_cDoorButtonEntityName));
     KvGetString(kv, "ff_button", g_cFFButtonEntityName, sizeof(g_cFFButtonEntityName));

     CloseHandle(kv);
     UpdateEntityLists();

     return true;
}

public void UpdateEntityLists() {
     // Clear all entities from the current lists
     ClearEntityLists();

     // Update cell door list
     int entity = 0;
     while ((entity = FindEntityByClassname(entity, g_cDoorEntityName)) != -1) {
          PushArrayCell(g_iDoorEntityList, entity);
     }

     // Update cell button list
     entity = 0;
     while ((entity = FindEntityByClassname(entity, g_cDoorButtonEntityName)) != -1) {
          PushArrayCell(g_iDoorButtonEntityList, entity);
     }

     // Update FF button list
     entity = 0;
     while ((entity = FindEntityByClassname(entity, g_cFFButtonEntityName)) != -1) {
          PushArrayCell(g_iFFButtonEntityList, entity);
     }
}

public void ClearEntityLists() {
     int i;

     // Clear cell door list
     for (i = 0; i < GetArraySize(g_iDoorEntityList); i++) {
          RemoveFromArray(g_iDoorEntityList, i);
     }

     // Clear cell button list
     for (i = 0; i < GetArraySize(g_iDoorButtonEntityList); i++) {
          RemoveFromArray(g_iDoorButtonEntityList, i);
     }

     // Clear ff button list
     for (i = 0; i < GetArraySize(g_iFFButtonEntityList); i++) {
          RemoveFromArray(g_iFFButtonEntityList, i);
     }
}


/** ==========[ NATIVES ]========== **/

public int Native_OpenCells(Handle plugin, int numParams) {
     OpenCells();
}

public int Native_CloseCells(Handle plugin, int numParams) {
     CloseCells();
}
