#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define L4D_TEAM_SPECTATOR 1
#define L4D_TEAM_SURVIVOR 2
#define L4D_TEAM_INFECTED 3

int g_survivorPlayers[4];
int g_infectedPlayers[4];
int g_survivorPlayerScores[4];
int g_infectedPlayerScores[4];
char g_currentDate[12];
float g_spectatorStartTimes[65];

public Plugin myinfo =
{
	name = "bizzstats",
	author = "Bizzy",
	description = "bizzystats is a lightweight stats plugin",
	version = "0.1",
	url = "http://bizzymod.com"
};

public void OnPluginStart() {
    PrintToServer("bizzstats loaded");
    HookEvent("round_end", OnRoundEnd);
    HookEvent("player_team", OnPlayerTeam);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
    int numClients = MaxClients;
    int numSurvivors = 0;
    int numInfected = 0;
    int survivorPoints = 0;
    int infectedPoints = 0;
    for (int i = 0; i < 4; i++) {
        g_survivorPlayers[i] = 0;
        g_infectedPlayers[i] = 0;
        g_survivorPlayerScores[i] = 0;
        g_infectedPlayerScores[i] = 0;
    }
    int totalSpectatingTime = 0;
    float roundTime = GetConVarFloat(FindConVar("mp_roundtime")) * 60.0;
    float timeLeft = GetGameTimeLeft();
    float roundDuration = roundTime - timeLeft;
    
    // Iterate through all clients to collect their stats
    for (int i = 1; i <= numClients; i++) {
        if (IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i)) {
            char playerName[MAX_NAME_LENGTH];
            GetClientName(i, playerName, sizeof(playerName));
            int playerTeam = GetPlayerTeam(i);
            int playerScore = GetClientScore(i);

            if (playerTeam == L4D_TEAM_SURVIVOR) {
                int index = numSurvivors - 1;
                if (index >= 0 && index < 4) {
                    g_survivorPlayers[index] = i;
                    g_survivorPlayerScores[index] = playerScore;
                }
            } else if (playerTeam == L4D_TEAM_INFECTED) {
                int index = numInfected - 1;
                if (index >= 0 && index < 4) {
                    g_infectedPlayers[index] = i;
                    g_infectedPlayerScores[index] = playerScore;
                }
            }
            
            // Add player score to the appropriate team
            if (playerTeam == L4D_TEAM_SURVIVOR) {
                numSurvivors++;
                survivorPoints += playerScore;
            } else if (playerTeam == L4D_TEAM_INFECTED) {
                numInfected++;
                infectedPoints += playerScore;
            }

            if (playerTeam == L4D_TEAM_SPECTATOR) {
                float spectatingTime = g_spectatorStartTimes[i] > 0 ? GetGameTime() - g_spectatorStartTimes[i] : 0.0;
                totalSpectatingTime += RoundToNearest(spectatingTime);
            }
        }
    }

    // Write the collected stats to a log file
    UpdateCurrentDate();
    char logLine[512];
    Format(logLine, sizeof(logLine), "Round End: Duration: %d, Survivors: %d, Infected: %d, Survivor Points: %d, Infected Points: %d, Spectating Time: %d\n",
        roundDuration, numSurvivors, numInfected, survivorPoints, infectedPoints, totalSpectatingTime);
    PrintToServer(logLine);
    WriteStatsToFile(logLine);

    char winningTeam[16];
    if (survivorPoints > infectedPoints) {
        strcopy(winningTeam, sizeof(winningTeam), "Survivors");
    } else {
        strcopy(winningTeam, sizeof(winningTeam), "Infected");
    }
    Format(logLine, sizeof(logLine), "Winning Team: %s\n", winningTeam);
    PrintToServer(logLine);
    WriteStatsToFile(logLine);

    for (int i = 0; i < 4; i++) {
        char survivorName[MAX_NAME_LENGTH];
        char infectedName[MAX_NAME_LENGTH];
        GetClientName(g_survivorPlayers[i], survivorName, sizeof(survivorName));
        GetClientName(g_infectedPlayers[i], infectedName, sizeof(infectedName));
        Format(logLine, sizeof(logLine), "Survivor %d: %s, Points: %d | Infected %d: %s, Points: %d\n", i + 1, survivorName, g_survivorPlayerScores[i], i + 1, infectedName, g_infectedPlayerScores[i]);
        PrintToServer(logLine);
        WriteStatsToFile(logLine);
    }
}

public void UpdateCurrentDate() {
    FormatTime(g_currentDate, sizeof(g_currentDate), "%Y-%m-%d");
}

public int GetPlayerTeam(int client) {
    int playerTeam = -1;
    GetEntProp(client, Prop_Send, "m_iTeamNum", playerTeam);
    return playerTeam;
}

public int GetClientScore(int client) {
    int playerScore = 0;
    GetEntProp(client, Prop_Data, "m_iFrags", playerScore);
    return playerScore;
}

public float GetGameTimeLeft() {
    float roundTime = GetConVarFloat(FindConVar("mp_roundtime")) * 60.0;
    float timeLeft = GetConVarFloat(FindConVar("mp_timeleft")) * 60.0;
    return roundTime - timeLeft;
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int newTeam = event.GetInt("team");
    int oldTeam = event.GetInt("oldteam");

    if (newTeam == L4D_TEAM_SPECTATOR) {
        g_spectatorStartTimes[client] = GetGameTimeLeft();
    } else if (oldTeam == L4D_TEAM_SPECTATOR && g_spectatorStartTimes[client] > 0 && (newTeam == L4D_TEAM_SURVIVOR || newTeam == L4D_TEAM_INFECTED)) {
        float roundTime = GetConVarFloat(FindConVar("mp_roundtime")) * 60.0;
        float timeLeftBefore = g_spectatorStartTimes[client];
        float timeLeftNow = GetGameTimeLeft();
        float spectatingTime = roundTime - timeLeftBefore - timeLeftNow;
        g_spectatorStartTimes[client] = 0.0;

        char playerName[MAX_NAME_LENGTH];
        GetClientName(client, playerName, sizeof(playerName));

        UpdateCurrentDate();
        char logLine[256];
        Format(logLine, sizeof(logLine), "Spectator: %s, Spectating Time: %.2f\n", playerName, spectatingTime);
        PrintToServer(logLine);
        WriteStatsToFile(logLine);
    }
}

public void WriteStatsToFile(const char[] logLine) {
    char logFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logFilePath, sizeof(logFilePath), "logs/L4D2Stats/%s.log", g_currentDate);

    File logFile = OpenFile(logFilePath, "a");
    if (logFile == null) {
        PrintToServer("Failed to open log file: %s", logFilePath);
        return;
    }

    // Write stats to the log file
    logFile.WriteLine(logLine);


    CloseHandle(logFile);
}