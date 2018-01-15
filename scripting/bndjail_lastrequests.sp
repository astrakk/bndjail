#include <sourcemod>
#include <bndjail>
#include <bndjail_lastrequests>

// Global variables and arrays
const int MAX_HANDLER_LENGTH = 32;
const int MAX_DESCRIPTION_LENGTH = 255;

ArrayList g_cLastRequestHandlers;
ArrayList g_cLastRequestDescriptions;
ArrayList g_cLastRequestQueue;
ArrayList g_iClientQueue;

int g_iLastRequestGivenClient = -1;

bool g_bIsLastRequestLocked = false;
bool g_bIsLastRequestGiven = false;
bool g_bIsLastRequestSelected = false;

Menu g_hGiveLastRequest;
Menu g_hSelectLastRequest;

// Forward handles
Handle g_hOnExecuteLastRequest
Handle g_hOnCleanLastRequest
Handle g_hOnGiveLastRequest
Handle g_hOnSelectLastRequest
Handle g_hOnCancelLastRequest

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
     HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

     // Create last request queue
     ClearLastRequests();

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
     CreateNative("BNDJail_IsLastRequestLocked", Native_IsLastRequestLocked);
     CreateNative("BNDJail_IsLastRequestGiven", Native_IsLastRequestGiven);
     CreateNative("BNDJail_IsLastRequestSelected", Native_IsLastRequestSelected);
     CreateNative("BNDJail_IsTodayLastRequest", Native_IsTodayLastRequest);
     CreateNative("BNDJail_IsTomorrowLastRequest", Native_IsTomorrowLastRequest);
     CreateNative("BNDJail_GetCurrentLastRequestClient", Native_GetCurrentLastRequestClient);
     CreateNative("BNDJail_GetCurrentLastRequestHandler", Native_GetCurrentLastRequestHandler);
     CreateNative("BNDJail_GetLastRequestDescription", Native_GetLastRequestDescription);

     // Forwards
     g_hOnExecuteLastRequest = CreateGlobalForward("BNDJail_OnExecuteLastRequest", ET_Event, Param_Cell);
     g_hOnCleanLastRequest = CreateGlobalForward("BNDJail_OnCleanLastRequest", ET_Event, Param_Cell);
     g_hOnGiveLastRequest = CreateGlobalForward("BNDJail_OnGiveLastRequest", ET_Event, Param_Any);
     g_hOnSelectLastRequest = CreateGlobalForward("BNDJail_OnSelectLastRequest", ET_Event, Param_Any);
     g_hOnCancelLastRequest = CreateGlobalForward("BNDJail_OnCancelLastRequest", ET_Event, Param_Cell);

     return APLRes_Success;
}

public void OnMapStart() {
     // Clear the last request queue
     ClearLastRequests();
}

public void BNDJail_OnRemovePlayerWarden(int client) {
     RemoveGiveLastRequestMenu();
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
     RemoveLastRequestSelected();

     if (IsTodayLastRequest()) {
          char handler[MAX_HANDLER_LENGTH];
          GetCurrentLastRequestHandler(handler, sizeof(handler));
          ExecuteLastRequest(GetCurrentLastRequestClient(), handler);
     }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
     ClearLastRequestMenus();
     LockLastRequest();

     if (!IsTomorrowLastRequest()) {
          AddLastRequest(-1, "LR_None");
     }

     if (IsTodayLastRequest()) {
          char handler[MAX_HANDLER_LENGTH];
          GetCurrentLastRequestHandler(handler, sizeof(handler));
          CleanLastRequest(GetCurrentLastRequestClient(), handler);
     }

     RemoveLastRequest();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
     int client = GetClientOfUserId(event.GetInt("userid"));

     // If the player who died was in the process of selecting their last request, remove their menu to prevent posthumous selection
     if (IsLastRequestGiven() && !IsLastRequestSelected()) {
          if (GetLastRequestGivenClient() == client) {
               RemoveSelectLastRequestMenu();
          }
     }
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
               SetLastRequestGiven(client);

               // Call the last request menu on the target client
               Menu_SelectLastRequest(client);

               // Notify the chat
               char cClientName[MAX_NAME_LENGTH];
               GetClientName(client, cClientName, sizeof(cClientName));

               PrintToChatAll("[JAIL] Warden has given %s their last request", cClientName);

               // Call the forward
               Call_StartForward(g_hOnGiveLastRequest);
               Call_PushCell(client);
               Call_Finish();
          }
     }

     return 0;
}

public Action Menu_SelectLastRequest(int client) {
     // Remove all items from menu
     RemoveAllMenuItems(g_hSelectLastRequest);

     char handler[MAX_HANDLER_LENGTH];
     char description[MAX_DESCRIPTION_LENGTH];

     // Iterate over all loaded last requests and display them in the menu
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
               AddLastRequest(param1, handler);

               // Set the status of LR selection to true
               SetLastRequestSelected();

               // Notify the chat
               char cClientName[MAX_NAME_LENGTH];
               GetClientName(param1, cClientName, sizeof(cClientName));

               PrintToChatAll("[JAIL] %s has selected their last request", cClientName);

               // Call the forward
               Call_StartForward(g_hOnSelectLastRequest);
               Call_PushCell(param1);
               Call_PushString(handler);
               Call_Finish();
          }
          case MenuAction_Cancel: {
               // Allow the warden to re-give LR if the menu is closed
               RemoveLastRequestGiven();

               // Notify the chat
               PrintToChatAll("[JAIL] Last request menu was closed without selecting anything");

               // Call the forward
               Call_StartForward(g_hOnCancelLastRequest);
               Call_PushCell(param1);
               Call_Finish();
          }
     }

     return 0;
}


/** ==========[ FUNCTIONS ]========== **/

public void ClearLastRequestMenus() {
     RemoveGiveLastRequestMenu();
     RemoveSelectLastRequestMenu();
}

public void RemoveGiveLastRequestMenu() {
     CancelMenu(g_hGiveLastRequest);

}

public void RemoveSelectLastRequestMenu() {
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

public void SetLastRequestGiven(int client) {
     g_iLastRequestGivenClient = client;
     g_bIsLastRequestGiven = true;
}

public void RemoveLastRequestGiven() {
     g_iLastRequestGivenClient = -1;
     g_bIsLastRequestGiven = false;
}

public int GetLastRequestGivenClient() {
     // Used to track who was given lr to check on player_death. DO NOT EXPOSE AS NATIVE.
     return g_iLastRequestGivenClient;
}

public void SetLastRequestSelected() {
     g_bIsLastRequestSelected = true;
}

public void RemoveLastRequestSelected() {
     g_bIsLastRequestSelected = false;
}

public bool IsLastRequestLocked() {
     return g_bIsLastRequestLocked;
}

public bool IsLastRequestGiven() {
     return g_bIsLastRequestGiven;
}

public bool IsLastRequestSelected() {
     return g_bIsLastRequestSelected;
}


public void ExecuteLastRequest(int client, const char[] handler) {
     // Call the forward
     Call_StartForward(g_hOnExecuteLastRequest);
     Call_PushCell(client);
     Call_PushString(handler);
     Call_Finish();

     // Actions for different handlers
     if (StrEqual(handler, "LR_DrugDayAll")) {
          Execute_LR_DrugDayAll();
     }

     else if (StrEqual(handler, "LR_DrugDayGuards")) {
          Execute_LR_DrugDayGuards();
     }
}

public void CleanLastRequest(int client, const char[] handler) {
     // Call the forward
     Call_StartForward(g_hOnCleanLastRequest);
     Call_PushCell(client);
     Call_PushString(handler);
     Call_Finish();

     // Actions for different handlers
     if (StrEqual(handler, "LR_DrugDayAll")) {
          Clean_LR_DrugDayAll();
     }

     else if (StrEqual(handler, "LR_DrugDayGuards")) {
          Clean_LR_DrugDayGuards();
     }
}


public void AddLastRequest(int client, const char[] handler) {
     PushArrayCell(g_iClientQueue, client);
     PushArrayString(g_cLastRequestQueue, handler);
}

public void RemoveLastRequest() {
     RemoveFromArray(g_iClientQueue, 0);
     RemoveFromArray(g_cLastRequestQueue, 0);
}

public void ClearLastRequests() {
     g_cLastRequestQueue = CreateArray(MAX_HANDLER_LENGTH);
     g_iClientQueue = CreateArray();

     AddLastRequest(-1, "LR_None");
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

public int GetCurrentLastRequestClient() {
     return GetArrayCell(g_iClientQueue, 0);
}

public bool GetCurrentLastRequestHandler(char[] handler, int size) {
     // There is no current LR
     if (!IsTodayLastRequest()) {
          return false;
     }

     // Retrieve the handler from the queue and return true
     GetArrayString(g_cLastRequestQueue, 0, handler, size);
     return true;
}

public bool GetLastRequestDescription(const char[] handler, char[] description, int size) {
     // Variables to store the handler and description
     char cArrayHandler[MAX_HANDLER_LENGTH];
     bool found = false;

     for (int i = 0; i < GetLastRequestCount(); i++) {
          GetArrayString(g_cLastRequestHandlers, i, cArrayHandler, sizeof(cArrayHandler));
          if (StrEqual(cArrayHandler, handler)) {
               GetArrayString(g_cLastRequestDescriptions, i, description, size);
               found = true;
               break;
          }
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

public int Native_IsLastRequestLocked(Handle plugin, int numParams) {
     return IsLastRequestLocked();
}

public int Native_IsLastRequestGiven(Handle plugin, int numParams) {
     return IsLastRequestGiven();
}

public int Native_IsLastRequestSelected(Handle plugin, int numParams) {
     return IsLastRequestSelected();
}

public int Native_IsTodayLastRequest(Handle plugin, int numParams) {
     return IsTodayLastRequest();
}

public int Native_IsTomorrowLastRequest(Handle plugin, int numParams) {
     return IsTomorrowLastRequest();
}

public int Native_GetCurrentLastRequestClient(Handle plugin, int numParams) {
     return GetCurrentLastRequestClient();
}

public int Native_GetCurrentLastRequestHandler(Handle plugin, int numParams) {
     // Retrieve the size and set up the handler string
     int size = GetNativeCell(2);
     char[] handler = new char[size];

     // Attempt to retrieve the current last request handler
     bool result = GetCurrentLastRequestHandler(handler, size);
     if (result) {
          SetNativeString(1, handler, size, false);
     }

     return result;
}

public int Native_GetLastRequestDescription(Handle plugin, int numParams) {

     // Retrieve the size, handler string, and set up the description string
     int size = GetNativeCell(3);
     char[] description = new char[size];

     int len;
     GetNativeStringLength(1, len);
     char[] handler = new char[len + 1];
     GetNativeString(1, handler, len + 1);

     // Attempt to retrieve the description of the provided LR
     bool result = GetLastRequestDescription(handler, description, size);
     if (result) {
          SetNativeString(2, description, size, false);
     }

     return result;
}
