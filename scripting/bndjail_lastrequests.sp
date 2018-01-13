#include <sourcemod>
#include <bndjail>

// Global variables and arrays
const int MAX_HANDLER_LENGTH = 32;
const int MAX_DESCRIPTION_LENGTH= 255;

ArrayList g_cLastRequestHandlers;
ArrayList g_cLastRequestDescriptions;
ArrayList g_cLastRequestQueue;

bool g_bIsLastRequestLocked = false;
bool g_bIsLastRequestGiven = false;

Menu g_hGiveLastRequest;
Menu g_hSelectLastRequest;

public Plugin myinfo = {
     name = "[TF2] BNDJail Last Requests",
     author = "Astrak",
     description = "Last Requests module for BNDJail",
     version = "1.0",
     url = "https://github.com/astrakk/"
};


/** ==========[ FORWARDS ]========== **/

public void OnPluginStart() {
     // Events
     HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
     HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);

     // Create last request queue
     g_cLastRequestQueue = CreateArray(64);
     AddLastRequest("LR_None");

     // Create the last request menus
     g_hGiveLastRequest = CreateMenu(Handler_GiveLastRequest);
     SetMenuTitle(g_hGiveLastRequest, "Who should receive LR?");

     g_hSelectLastRequest = CreateMenu(Handler_SelectLastRequest);
     SetMenuTitle(g_hSelectLastRequest, "What do you want to do tomorrow?");

     // Public commands
     RegConsoleCmd("sm_givelr", Command_GiveLastRequest, "As warden, select a living red player to give a last request");

     // Load config
     LoadConfig("addons/sourcemod/configs/bndjail/bndjail_lastrequests.cfg");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
     // Dependency
     RegPluginLibrary("bndjail_lastrequests");

     // Natives
     CreateNative("BNDJail_GetLastRequestDescription", Native_GetLastRequestDescription);

     return APLRes_Success;
}

/** ==========[ COMMANDS ]========== **/

public Action Command_GiveLastRequest(int client, int args) {
     // Client not warden
     if (!BNDJail_IsPlayerWarden(client)) {
          PrintToChat(client, "[JAIL] Error: you are not the warden");
          return Plugin_Handled;
     }

     // Last request already given
     if (IsLastRequestGiven()) {
          PrintToChat(client, "[JAIL] Error: last request has already been given");
          return Plugin_Handled;
     }
     
     Menu_GiveLastRequest(client);

     return Plugin_Handled;
}


/** ==========[ EVENTS ] ========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     UnlockLastRequest();
     RemoveLastRequestGiven();

     if (IsTodayLastRequest()) {
          char handler[MAX_HANDLER_LENGTH];
          GetArrayString(g_cLastRequestQueue, 0, handler, sizeof(handler));
          ExecuteLastRequest(handler);
     }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
     CancelLastRequestMenus();
     LockLastRequest();

     if (!IsTomorrowLastRequest()) {
          AddLastRequest("LR_None");
     }

     if (IsTodayLastRequest()) {
          char handler[MAX_HANDLER_LENGTH];
          GetArrayString(g_cLastRequestQueue, 0, handler, sizeof(handler));
          CleanLastRequest(handler);
     }

     RemoveLastRequest();
}


/** ==========[ MENUS ] ========== **/

public Action Menu_GiveLastRequest(int client) {
     // Remove all items from menu
     RemoveAllMenuItems(g_hGiveLastRequest);

     // Variable to store the player names in
     char id[8];
     char name[MAX_NAME_LENGTH];

     // Iterate over all players and add their name to the menu if they're alive and on red team
     for (int i = 0; i < MaxClients; i++) {
          if (IsValidClient(i, false, true, true) && BNDJail_IsPlayerRed(i)) {
               IntToString(i, id, sizeof(id));
               GetClientName(i, name, sizeof(name));
               AddMenuItem(g_hGiveLastRequest, id, name);
          }
     }

     DisplayMenu(g_hGiveLastRequest, client, MENU_TIME_FOREVER);

     return Plugin_Handled;
}

public int Handler_GiveLastRequest(Menu menu, MenuAction action, int param1, int param2) {
     switch(action) {
          case MenuAction_Select: {
               // Last request was locked
               if (IsLastRequestLocked()) {
                    return 0;
               }

               // Get the client id of the selected player
               char id[8];
               GetMenuItem(menu, param2, id, sizeof(id));

               // Convert the id from a string to an int
               int client = StringToInt(id);

               // Set the last request as given
               SetLastRequestGiven();

               // Call the last request menu on the target client
               Menu_SelectLastRequest(client);

               // Notify the chat
               char cClientName[MAX_NAME_LENGTH];
               GetClientName(client, cClientName, sizeof(cClientName));

               PrintToChatAll("[JAIL] Warden has given %s their last request", cClientName);
          }
     }

     return 0;
}

public Action Menu_SelectLastRequest(int client) {
     // Remove all items from menu
     RemoveAllMenuItems(g_hSelectLastRequest);

     //AddMenuItem(g_hSelectLastRequest, "LR_DrugDayAll", "Drug day (all)");
     //AddMenuItem(g_hSelectLastRequest, "LR_DrugDayGuards", "Drug day (guards)");

     char handler[MAX_HANDLER_LENGTH];
     char description[MAX_DESCRIPTION_LENGTH];

     for (int i = 0; i < GetLastRequestCount(); i++) {
          GetArrayString(g_cLastRequestHandlers, i, handler, sizeof(handler));
          GetArrayString(g_cLastRequestDescriptions, i, description, sizeof(description));
          
          AddMenuItem(g_hSelectLastRequest, handler, description);
     }

     DisplayMenu(g_hSelectLastRequest, client, MENU_TIME_FOREVER);

     return Plugin_Handled;
}

public int Handler_SelectLastRequest(Menu menu, MenuAction action, int param1, int param2) {
     switch (action) {
          case MenuAction_Select: {
               // Last request was locked
               if (IsLastRequestLocked()) {
                    return 0;
               }

               // Get the LR handler from the selected menu item
               char handler[MAX_HANDLER_LENGTH];
               GetMenuItem(menu, param2, handler, sizeof(handler));

               // Add the selected LR to the queue
               AddLastRequest(handler);

               // Notify the chat
               char cClientName[MAX_NAME_LENGTH];
               GetClientName(param1, cClientName, sizeof(cClientName));

               PrintToChatAll("[JAIL] %s has selected their last request", cClientName);
          }
          case MenuAction_Cancel: {
               // Allow the warden to re-give LR if the menu is closed
               RemoveLastRequestGiven();

               // Notify the chat
               PrintToChatAll("[JAIL] Last request menu was closed without selecting anything");
          }
     }

     return 0;
}


/** ==========[ FUNCTIONS ]========== **/

public void CancelLastRequestMenus() {
     CancelMenu(g_hGiveLastRequest);
     CancelMenu(g_hSelectLastRequest);
}

public void LockLastRequest() {
     g_bIsLastRequestLocked = true;
     PrintToChatAll("[JAIL] Last request is now locked");
}

public void UnlockLastRequest() {
     g_bIsLastRequestLocked = false;
     PrintToChatAll("[JAIL] Last request is now unlocked");
}

public void SetLastRequestGiven() {
     g_bIsLastRequestGiven = true;
}

public void RemoveLastRequestGiven() {
     g_bIsLastRequestGiven = false;
}

public bool IsLastRequestLocked() {
     return g_bIsLastRequestLocked;
}

public bool IsLastRequestGiven() {
     return g_bIsLastRequestGiven;
}


public void ExecuteLastRequest(const char handler[MAX_HANDLER_LENGTH]) {
     if (StrEqual(handler, "LR_DrugDayAll")) {
          Execute_LR_DrugDayAll();
     }

     else if (StrEqual(handler, "LR_DrugDayGuards")) {
          Execute_LR_DrugDayGuards();
     }
}

public void CleanLastRequest(const char handler[MAX_HANDLER_LENGTH]) {
     if (StrEqual(handler, "LR_DrugDayAll")) {
          Clean_LR_DrugDayAll();
     }

     else if (StrEqual(handler, "LR_DrugDayGuards")) {
          Clean_LR_DrugDayGuards();
     }
}


public void AddLastRequest(const char handler[MAX_HANDLER_LENGTH]) {
     PushArrayString(g_cLastRequestQueue, handler);
}

public void RemoveLastRequest() {
     RemoveFromArray(g_cLastRequestQueue, 0);
}


public bool IsTodayLastRequest() {
     char handler[MAX_HANDLER_LENGTH];
     if (GetArrayString(g_cLastRequestQueue, 0, handler, sizeof(handler)))
     {
          if (!StrEqual(handler, "LR_None")) {
               return true;
          }
     }

     return false;
}

public bool IsTomorrowLastRequest() {
     char handler[MAX_HANDLER_LENGTH];
     if (GetArraySize(g_cLastRequestQueue) < 2) {
          return false;
     }
     else if (GetArrayString(g_cLastRequestQueue, 1, handler, sizeof(handler)))
     {
          if (!StrEqual(handler, "LR_None")) {
               return true;
          }
     }

     return false;
}


public bool LoadConfig(const char[] config) {
     // Create the arrays
     g_cLastRequestHandlers = CreateArray(MAX_HANDLER_LENGTH);
     g_cLastRequestDescriptions = CreateArray(MAX_DESCRIPTION_LENGTH);

     KeyValues kv = new KeyValues("Last Requests");

     // Could not read config file
     if (!FileToKeyValues(kv, config)) {
          PrintToServer("[JAIL] Error: failed to open lastrequests config file");
          CloseHandle(kv);
          return false;
     }

     // Could not find subkeys in config file
     if (!KvGotoFirstSubKey(kv)) {
          PrintToServer("[JAIL] Error: failed to find subkey in lastrequests config file. Is it empty?");
          CloseHandle(kv);
          return false;
     }

     // Iterate over all subkeys and store their contents in appropriate arrays
     char handler[MAX_HANDLER_LENGTH];
     char description[MAX_DESCRIPTION_LENGTH];

     do {
          KvGetSectionName(kv, handler, sizeof(handler));
          KvGetString(kv, "desc", description, sizeof(description));

          // Store the retrieved values
          PushArrayString(g_cLastRequestHandlers, handler);
          PushArrayString(g_cLastRequestDescriptions, description);
     } while (KvGotoNextKey(kv));

     // Array sizes don't match (missing description or handler value)
     if (GetArraySize(g_cLastRequestHandlers) != GetArraySize(g_cLastRequestDescriptions)) {
          PrintToServer("[JAIL] Error: invalid data in config file. Please check all handlers and descriptions");
          CloseHandle(kv);
          return false;
     }

     // Close the KeyValues handle and return true
     CloseHandle(kv);
     return true;
}


public int GetLastRequestCount() {
     return GetArraySize(g_cLastRequestHandlers);
}

public bool GetLastRequestDescription(char[] name, int size) {
     // Variables to store the handler and description
     char cCurrentHandler[MAX_HANDLER_LENGTH];
     char handler[MAX_HANDLER_LENGTH];
     char description[MAX_DESCRIPTION_LENGTH];
     bool found = false;

     if (IsTodayLastRequest()) {
          GetArrayString(g_cLastRequestQueue, 0, cCurrentHandler, sizeof(cCurrentHandler));
          for (int i = 0; i < GetLastRequestCount(); i++) {
               GetArrayString(g_cLastRequestHandlers, i, handler, sizeof(handler));
               if (StrEqual(cCurrentHandler, handler)) {
                    GetArrayString(g_cLastRequestDescriptions, i, description, sizeof(description));
                    found = true;
                    break;
               }
          }
     }

     if (found) {
          strcopy(name, size, description);
     }

     return found;
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


/** ==========[ LAST REQUESTS (EXECUTION) ]========== **/

Execute_LR_DrugDayAll() {
     ServerCommand("sm_drug @all 1");
}

Execute_LR_DrugDayGuards() {
     ServerCommand("sm_drug @blue 1");
}


/** ==========[ LAST REQUESTS (CLEANING) ]========== **/

Clean_LR_DrugDayAll() {
     ServerCommand("sm_drug @all 0");
}

Clean_LR_DrugDayGuards() {
     ServerCommand("sm_drug @all 0");
}


/** ==========[ NATIVES ]========== **/

public int Native_GetLastRequestDescription(Handle plugin, int numParams) {
     int size = GetNativeCell(2);
     char description[size] = GetNativeCell(1);

     return GetLastRequestDescription(description, size);
}
