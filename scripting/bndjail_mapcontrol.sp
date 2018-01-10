#include <sourcemod>
#include <sdktools>

#include <bndjail>
#include <bndjail_mapcontrol>

#pragma semicolon 1
#pragma newdecls required

// Global variables and arrays
ArrayList g_iDoorEntities;
ArrayList g_iDoorButtonEntities;
ArrayList g_iFFButtonEntities;

char g_cDoorName[64];
char g_cDoorButtonName[64];
char g_cFFButtonName[64];

bool g_bIsMapConfigLoaded = false;

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
     RegConsoleCmd("sm_close", Command_CloseCells, "Close the cell doors as warden");

     // Admin commands
     RegAdminCmd("sm_forceopen", Admin_OpenCells, 6, "Open the cell doors as an admin");
     RegAdminCmd("sm_forceclose", Admin_CloseCells, 6, "Close the cell doors as an admin");

     // Create entity index arrays
     g_iDoorEntities = CreateArray(32);
     g_iDoorButtonEntities = CreateArray(32);
     g_iFFButtonEntities = CreateArray(32);

     // Translations
     LoadTranslations("common.phrases");

     // Read map config
     g_bIsMapConfigLoaded = LoadConfig("addons/sourcemod/configs/bndjail/bndjail_mapcontrol.cfg");

     // Create entity lists if map config loaded
     if (IsMapConfigLoaded()) {
          UpdateEntityLists();
     }
}

public void OnMapStart() {
     // Read map config
     g_bIsMapConfigLoaded = LoadConfig("addons/sourcemod/configs/bndjail/bndjail_mapcontrol.cfg");
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
     // Map not compatible
     if (!IsMapConfigLoaded()) {
          return Plugin_Handled;
     }

     // Player not warden
     if (!BNDJail_IsPlayerWarden(client)) {
          return Plugin_Handled;
     }

     OpenCells();

     return Plugin_Handled;
}

public Action Command_CloseCells(int client, int args) {
     // Map not compatible
     if (!IsMapConfigLoaded()) {
          return Plugin_Handled;
     }

     // Player not warden
     if (!BNDJail_IsPlayerWarden(client)) {
          return Plugin_Handled;
     }

     CloseCells();

     return Plugin_Handled;
}


// Admin commands
public Action Admin_OpenCells(int client, int args) {
     // Map not compatible
     if (!IsMapConfigLoaded()) {
          return Plugin_Handled;
     }

     OpenCells();

     Call_StartForward(g_hOnOpenCells);
     Call_Finish();

     return Plugin_Handled;
}

public Action Admin_CloseCells(int client, int args) {
     // Map not compatible
     if (!IsMapConfigLoaded()) {
          return Plugin_Handled;
     }

     CloseCells();

     Call_StartForward(g_hOnCloseCells);
     Call_Finish();

     return Plugin_Handled;
}


/** ===========[ EVENTS ]=========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     // Map is compatible
     if (IsMapConfigLoaded()) {
          UpdateEntityLists();
     }
}


/** ===========[ FUNCTIONS ]=========== **/

// Door control functions
public void OpenCells() {
     for (int i = 0; i < GetArraySize(g_iDoorEntities); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorEntities, i), "Open");
     }
}

public void CloseCells() {
     for (int i = 0; i < GetArraySize(g_iDoorEntities); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorEntities, i), "Close");
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

     KvGetString(kv, "door_name", g_cDoorName, sizeof(g_cDoorName));
     KvGetString(kv, "door_button", g_cDoorButtonName, sizeof(g_cDoorButtonName));
     KvGetString(kv, "ff_button", g_cFFButtonName, sizeof(g_cFFButtonName));

     CloseHandle(kv);

     return true;
}

public bool IsMapConfigLoaded() {
     return g_bIsMapConfigLoaded;
}

// Entity list functions
public void CreateDoorList(ArrayList array, const char[] name) {
     // Remove all items from array
     ClearArray(array);

     // Prepare variables to compare classnames
     char cDoorClassnames[][] = { "func_door", "func_door_rotating", "func_movelinear" };
     char cEntityClassname[64];
     int entity = -1;

     // Look for matching classnames and compare m_iName to config file
     for (int i = 0; i < sizeof(cDoorClassnames); i++) {
          while ((entity = FindEntityByClassname(entity, cDoorClassnames[i])) != -1) {
               // Retrieve the entity m_iName
               GetEntPropString(entity, Prop_Data, "m_iName", cEntityClassname, sizeof(cEntityClassname));
               if (StrEqual(cEntityClassname, name)) {
                    PushArrayCell(array, entity);
               }
          }
     }
}

public void CreateButtonList(ArrayList array, const char[] name) {
     // Remove all items from array
     ClearArray(array);

     // Prepare variables to compare classnames
     char cButtonClassname[] = "func_button";
     char cEntityClassname[64];
     int entity = -1;

     // Look for matching classnames and compare m_iName to config file
     while ((entity = FindEntityByClassname(entity, cButtonClassname)) != -1) {
          // Retrieve the entity m_iName
          GetEntPropString(entity, Prop_Data, "m_iName", cEntityClassname, sizeof(cEntityClassname));
          if (StrEqual(cEntityClassname, name)) {
               PushArrayCell(array, entity);
          }
     }
}


public void UpdateEntityLists() {
     // Create entity lists using new variables
     CreateDoorList(g_iDoorEntities, g_cDoorName);
     CreateButtonList(g_iDoorButtonEntities, g_cDoorButtonName);
     CreateButtonList(g_iFFButtonEntities, g_cFFButtonName);
}


/** ==========[ NATIVES ]========== **/

public int Native_OpenCells(Handle plugin, int numParams) {
     OpenCells();
}

public int Native_CloseCells(Handle plugin, int numParams) {
     CloseCells();
}
