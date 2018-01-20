#include <sourcemod>
#include <bndjail>

// Global variables and arrays
const int START_TIME_LEFT = 600;
Handle g_hTimer;
Handle g_hTimerText;

int g_iTimeLeft;

bool g_bIsTimerPaused = false;

public Plugin myinfo = {
	name = "[TF2] BNDJail RoundTimer",
	author = "Astrak",
	description = "Round Timer module for BNDJail ",
	version = "1.0",
	url = "https://github.com/astrakk/bndjail"
};


/** ==========[ FORWARDS ]========== **/

public void OnPluginStart() {
     // Events
     HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
     HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);

     // Admin commands
     RegAdminCmd("sm_pause", Admin_PauseTimer, 6, "Temporarily pause the round timer as an admin");
     RegAdminCmd("sm_resume", Admin_ResumeTimer, 6, "Resume a paused timer");

     // HUD
     g_hTimerText = CreateHudSynchronizer();
}

public void OnPluginEnd() {
     EndTimer();
}

/** ==========[ COMMANDS ]========== **/

// Admin commands
public Action Admin_PauseTimer(int client, int args) {
     // Timer is already paused
     if (IsTimerPaused()) {
          PrintToChat(client, "[JAIL] Error: timer is already paused. Type !resume to resume it.");
          return Plugin_Handled;
     }

     PauseTimer();
     return Plugin_Handled;
}

public Action Admin_ResumeTimer(int client, int args) {
     // Timer is already resumed 
     if (!IsTimerPaused()) {
          PrintToChat(client, "[JAIL] Error: timer is already resumed. Type !pause to pause it.");
          return Plugin_Handled;
     }

     ResumeTimer();
     return Plugin_Handled;
}


/** ==========[ EVENTS ]========== **/

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
     StartTimer();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
     EndTimer();
}

/** ==========[ TIMERS ]========== **/
public Action Timer_RoundTimer(Handle timer) {
     // Increment the timeleft backwards if not paused
     if (!IsTimerPaused()) {
          g_iTimeLeft--;
     }

     SetTimerText();

     // Check if the timer has ended
     if (g_iTimeLeft <= 0) {
          ServerCommand("sm_slay @red");
          EndTimer();
          return Plugin_Stop;
     }

     return Plugin_Continue;
}


/** ==========[ FUNCTIONS ]========== **/

// Timer functions
public bool StartTimer() {
     if (g_hTimer == INVALID_HANDLE) {
          g_iTimeLeft = START_TIME_LEFT;
          SetTimerText();
          g_hTimer = CreateTimer(1.0, Timer_RoundTimer, _, TIMER_REPEAT);
          ResumeTimer();
          return true;
     }

     return false;
}

public bool EndTimer() {
     if (g_hTimer != INVALID_HANDLE) {
          ClearTimerText();
          KillTimer(g_hTimer);
          g_hTimer = INVALID_HANDLE;
          ResumeTimer();
          return true;
     }

     return false;
}

// HUD functions (to be moved to bndjail_hud eventually)
public void FormatSeconds(int seconds, char[] destination, int size) {
     int minutes = (seconds / 60 % 60);
     seconds = (seconds % 60);

     Format(destination, size, "%02dm %02ds", minutes, seconds);
}

public void SetTimerText() {
     // Format the current time left correctly
     char cTimeLeft[128];
     FormatSeconds(g_iTimeLeft, cTimeLeft, sizeof(cTimeLeft));
     
     // Append "(paused)" to timer if timer is paused
     if (IsTimerPaused()) {
          Format(cTimeLeft, sizeof(cTimeLeft), "%s (paused)", cTimeLeft);
     }

     // Set the timer text on all clients
     SetHudTextParams(0.05, 0.08, 60.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);

     for (int i = 0; i < MaxClients; i++) {
          if (IsValidClient(i, true, true, false)) {
               ShowSyncHudText(i, g_hTimerText, cTimeLeft);
          }
     }

}

public void ClearTimerText() {
     // Clear the timer text on all clients
     for (int i = 0; i < MaxClients; i++) {
          if (IsValidClient(i, true, true, false)) {
               ClearSyncHud(i, g_hTimerText);
          }
     }
}

// Pause functions
public bool IsTimerPaused() {
     return g_bIsTimerPaused;
}

public void PauseTimer() {
     g_bIsTimerPaused = true;
}

public void ResumeTimer() {
     g_bIsTimerPaused = false;
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
     if(  !(1 <= client <= MaxClients) ||              /* Is the client a player? */
          (!IsClientInGame(client)) ||                 /* Is the client in-game? */
          (IsPlayerAlive(client) && !bAllowAlive) ||   /* Is the client allowed to be alive? */
          (!IsPlayerAlive(client) && !bAllowDead) ||   /* Is the client allowed to be dead? */
          (IsFakeClient(client) && !bAllowBots)) {     /* Is the client allowed to be a bot? */
               return false;
     }
     return true;
}

// TO-DO: - Add natives for PauseTimer, ResumeTimer, StartTimer, EndTimer, IsTimerPaused, etc
//        - Move the timer HUD elements into bndjail_hud
