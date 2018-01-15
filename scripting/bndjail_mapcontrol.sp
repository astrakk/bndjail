#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <bndjail>
#include <bndjail_mapcontrol>

#pragma semicolon 1
#pragma newdecls required

// Global variables and arrays
char g_cDoorClassnames[][] = { "func_door", "func_door_rotating", "func_movelinear" };
ArrayList g_iDoorList;

char g_cDoorName[64];
char g_cButtonName[64];
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
     HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);

     // Public commands
     RegConsoleCmd("sm_open", Command_OpenCells, "Open the cell doors as warden");
     RegConsoleCmd("sm_close", Command_CloseCells, "Close the cell doors as warden");

     // Admin commands
     RegAdminCmd("sm_forceopen", Admin_OpenCells, 6, "Open the cell doors as an admin");
     RegAdminCmd("sm_forceclose", Admin_CloseCells, 6, "Close the cell doors as an admin");

     // Translations
     LoadTranslations("common.phrases");

     // Read map config
     g_bIsMapConfigLoaded = LoadConfig("addons/sourcemod/configs/bndjail/bndjail_mapcontrol.cfg");

     // Create door list and hook warden buttons
     if (IsMapConfigLoaded()) {
          CreateDoorList();
          HookAllButtons();
     }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
     // Dependency
     RegPluginLibrary("bndjail_mapcontrol");

     // Natives
     CreateNative("BNDJail_OpenCells", Native_OpenCells);
     CreateNative("BNDJail_CloseCells", Native_CloseCells);

     CreateNative("BNDJail_GetDoorCount", Native_GetDoorCount);

     // Forwards
     g_hOnOpenCells = CreateGlobalForward("BNDJail_OnOpenCells", ET_Event);
     g_hOnCloseCells = CreateGlobalForward("BNDJail_OnCloseCells", ET_Event);

     return APLRes_Success;
}


/** ==========[ EVENTS ]========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     if (IsMapConfigLoaded()) {
          CreateDoorList();
          HookAllButtons();
     }
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

     return Plugin_Handled;
}

public Action Admin_CloseCells(int client, int args) {
     // Map not compatible
     if (!IsMapConfigLoaded()) {
          return Plugin_Handled;
     }

     CloseCells();

     return Plugin_Handled;
}


/** ==========[ HOOKS ]========== **/

public Action Hook_OnButtonPress(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
     // Negate button press if attacker is not warden
     if (IsValidClient(attacker)) {
          if (!BNDJail_IsPlayerWarden(attacker)) {
               return Plugin_Handled;
          }
     }

     return Plugin_Continue;
}


/** ===========[ FUNCTIONS ]=========== **/

// Door control functions
public void OpenCells() {
     for (int i = 0; i < GetDoorCount(); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorList, i), "Open");
     }

     Call_StartForward(g_hOnOpenCells);
     Call_Finish();
}

public void CloseCells() {
     for (int i = 0; i < GetDoorCount(); i++) {
          AcceptEntityInput(GetArrayCell(g_iDoorList, i), "Close");
     }

     Call_StartForward(g_hOnCloseCells);
     Call_Finish();
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
     KvGetString(kv, "door_button", g_cButtonName, sizeof(g_cButtonName));
     KvGetString(kv, "ff_button", g_cFFButtonName, sizeof(g_cFFButtonName));

     CloseHandle(kv);

     return true;
}

public bool IsMapConfigLoaded() {
     return g_bIsMapConfigLoaded;
}

public bool CreateDoorList() {
     // Create a new array
     g_iDoorList = CreateArray(32);

     // Create variables required to locate doors
     int iEntity = -1;

     // Search for valid doors and add them to the list
     for (int i = 0; i < sizeof(g_cDoorClassnames); i++) {
          while ((iEntity = FindEntityByClassname(iEntity, g_cDoorClassnames[i])) != -1) {
               if (EntityNameEqual(iEntity, g_cDoorName)) {
                    AddToDoorList(iEntity);
               }
          }
     }
}

public void AddToDoorList(int entity) {
     PushArrayCell(g_iDoorList, entity);
}

public bool EntityNameEqual(int entity, const char[] name) {
     char cEntityName[64];

     // Get the entity name
     GetEntPropString(entity, Prop_Data, "m_iName", cEntityName, sizeof(cEntityName));

     // Compare to the provided string
     if (StrEqual(cEntityName, name)) {
          return true;
     }

     return false;
}

public int GetDoorCount() {
     return GetArraySize(g_iDoorList);
}


public void HookAllButtons() {
     int iEntity = -1;
     while ((iEntity = FindEntityByClassname(iEntity, "func_button")) != -1) {
          if (EntityNameEqual(iEntity, g_cButtonName) || EntityNameEqual(iEntity, g_cFFButtonName)) {
               HookButtonPress(iEntity);
          }
     }
}


public void HookButtonPress(int entity) {
     SDKHook(entity, SDKHook_OnTakeDamage, Hook_OnButtonPress);
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


/** ==========[ NATIVES ]========== **/

public int Native_OpenCells(Handle plugin, int numParams) {
     OpenCells();
}

public int Native_CloseCells(Handle plugin, int numParams) {
     CloseCells();
}

public int Native_GetDoorCount(Handle plugin, int numParams) {
     return GetDoorCount();
}
