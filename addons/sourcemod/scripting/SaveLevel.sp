#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <outputinfo>

#pragma newdecls required

StringMap g_PlayerLevels;
KeyValues g_Config;
KeyValues g_PropAltNames;

#define PLUGIN_VERSION "2.0"
public Plugin myinfo =
{
	name 			= "SaveLevel",
	author 			= "BotoX",
	description 	= "Saves players level on maps when they disconnect and restore them on connect.",
	version 		= PLUGIN_VERSION,
	url 			= ""
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_PropAltNames = new KeyValues("PropAltNames");
	g_PropAltNames.SetString("m_iName", "targetname");

	RegAdminCmd("sm_level", Command_Level, ADMFLAG_GENERIC, "Set a players map level.");
}

public void OnPluginEnd()
{
	if(g_Config)
		delete g_Config;
	if(g_PlayerLevels)
		delete g_PlayerLevels;
	delete g_PropAltNames;
}

public void OnMapStart()
{
	if(g_Config)
		delete g_Config;
	if(g_PlayerLevels)
		delete g_PlayerLevels;

	char sMapName[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/savelevel/%s.cfg", sMapName);
	if(!FileExists(sConfigFile))
	{
		LogMessage("Could not find mapconfig: \"%s\"", sConfigFile);
		return;
	}
	LogMessage("Found mapconfig: \"%s\"", sConfigFile);

	g_Config = new KeyValues("levels");
	if(!g_Config.ImportFromFile(sConfigFile))
	{
		delete g_Config;
		LogMessage("ImportFromFile() failed!");
		return;
	}
	g_Config.Rewind();

	if(!g_Config.GotoFirstSubKey())
	{
		delete g_Config;
		LogMessage("GotoFirstSubKey() failed!");
		return;
	}

	g_PlayerLevels = new StringMap();
}

public void OnClientPostAdminCheck(int client)
{
	if(!g_Config)
		return;

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID));

	static char sTargets[128];
	if(g_PlayerLevels.GetString(sSteamID, sTargets, sizeof(sTargets)))
	{
		g_PlayerLevels.Remove(sSteamID);

		char sNames[128];
		static char asTargets[4][32];
		int Split = ExplodeString(sTargets, ";", asTargets, sizeof(asTargets), sizeof(asTargets[]));

		int Found = 0;
		for(int i = 0; i < Split; i++)
		{
			static char sName[32];
			if(RestoreLevel(client, asTargets[i], sName, sizeof(sName)))
			{
				if(Found)
					StrCat(sNames, sizeof(sNames), ", ");
				Found++;

				StrCat(sNames, sizeof(sNames), sName);
			}
		}

		if(Found)
			PrintToChatAll("\x03[SaveLevel]\x01 \x04%N\x01 has been restored to: \x04%s", client, sNames);
	}
}

public void OnClientDisconnect(int client)
{
	if(!g_Config || !g_PlayerLevels || !IsClientInGame(client))
		return;

	char sTargets[128];
	if(GetLevel(client, sTargets, sizeof(sTargets)))
	{
		char sSteamID[32];
		GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID));
		g_PlayerLevels.SetString(sSteamID, sTargets, true);
	}
}

bool RestoreLevel(int client, const char[] sTarget, char[] sName = NULL_STRING, int NameLen = 0)
{
	g_Config.Rewind();

	if(!g_Config.JumpToKey(sTarget))
		return false;

	if(NameLen)
		g_Config.GetString("name", sName, NameLen);

	static char sKey[32];
	static char sValue[1024];

	if(!g_Config.JumpToKey("restore"))
		return false;

	if(!g_Config.GotoFirstSubKey(false))
		return false;

	do
	{
		g_Config.GetSectionName(sKey, sizeof(sKey));
		g_Config.GetString(NULL_STRING, sValue, sizeof(sValue));
		if(StrEqual(sKey, "AddOutput", false))
		{
			SetVariantString(sValue);
			AcceptEntityInput(client, sKey, client, client);
		}
		else if(StrEqual(sKey, "DeleteOutput", false))
		{
			int Index;
			// Output (e.g. m_OnUser1)
			int Target = FindCharInString(sValue, ' ');
			if(Target == -1)
			{
				while((Index = FindOutput(client, sValue, 0)) != -1)
					DeleteOutput(client, sValue, Index);

				continue;
			}
			sValue[Target] = 0; Target++;
			while(IsCharSpace(sValue[Target]))
				Target++;

			// Target (e.g. leveling_counter)
			int Input = FindCharInString(sValue[Target], ',');
			if(Input == -1)
			{
				while((Index = FindOutput(client, sValue, 0, sValue[Target])) != -1)
					DeleteOutput(client, sValue, Index);

				continue;
			}
			sValue[Input] = 0; Input++;

			// Input (e.g. add)
			int Parameter = Input + FindCharInString(sValue[Input], ',');
			if(Input == -1)
			{
				while((Index = FindOutput(client, sValue, 0, sValue[Target], sValue[Input])) != -1)
					DeleteOutput(client, sValue, Index);

				continue;
			}
			sValue[Parameter] = 0; Parameter++;

			// Parameter (e.g. 1)
			while((Index = FindOutput(client, sValue, 0, sValue[Target], sValue[Input], sValue[Parameter])) != -1)
				DeleteOutput(client, sValue, Index);
		}
		else
		{
			PropFieldType Type;
			int NumBits;
			int Offset = FindDataMapInfo(client, sKey, Type, NumBits);
			if(Offset != -1)
			{
				if(Type == PropField_Integer)
				{
					int Value = StringToInt(sValue);
					SetEntData(client, Offset, Value, NumBits / 8, false);
				}
				else if(Type == PropField_Float)
				{
					float Value = StringToFloat(sValue);
					SetEntDataFloat(client, Offset, Value, false);
				}
				else if(Type == PropField_String)
				{
					SetEntDataString(client, Offset, sValue, strlen(sValue) + 1, false);
				}
				else if(Type == PropField_String_T)
				{
					static char sAltKey[32];
					g_PropAltNames.GetString(sKey, sAltKey, sizeof(sAltKey), NULL_STRING);
					if(sAltKey[0])
						DispatchKeyValue(client, sAltKey, sValue);
				}
			}
		}
	}
	while(g_Config.GotoNextKey(false));

	g_Config.Rewind();
	return true;
}

bool GetLevel(int client, char[] sTargets, int TargetsLen, char[] sNames = NULL_STRING, int NamesLen = 0)
{
	if(!g_Config || !g_PlayerLevels || !IsClientInGame(client))
		return false;

	g_Config.Rewind();
	g_Config.GotoFirstSubKey();

	static char sTarget[32];
	static char sName[32];
	static char sKey[32];
	static char sValue[1024];
	static char sOutput[1024];
	bool Found = false;
	do
	{
		g_Config.GetSectionName(sTarget, sizeof(sTarget));
		g_Config.GetString("name", sName, sizeof(sName));

		if(!g_Config.JumpToKey("match"))
			continue;

		int Matches = 0;
		int ExactMatches = g_Config.GetNum("ExactMatches", -1);
		int MinMatches = g_Config.GetNum("MinMatches", -1);
		int MaxMatches = g_Config.GetNum("MaxMatches", -1);

		if(!g_Config.GotoFirstSubKey(false))
			continue;

		do
		{
			static char sSection[32];
			g_Config.GetSectionName(sSection, sizeof(sSection));

			if(StrEqual(sSection, "outputs"))
			{
				int _Matches = 0;
				int _ExactMatches = g_Config.GetNum("ExactMatches", -1);
				int _MinMatches = g_Config.GetNum("MinMatches", -1);
				int _MaxMatches = g_Config.GetNum("MaxMatches", -1);

				if(g_Config.GotoFirstSubKey(false))
				{
					do
					{
						g_Config.GetSectionName(sKey, sizeof(sKey));
						g_Config.GetString(NULL_STRING, sValue, sizeof(sValue));

						int Count = GetOutputCount(client, sKey);
						for(int i = 0; i < Count; i++)
						{
							GetOutputFormatted(client, sKey, i, sOutput, sizeof(sOutput));
							sOutput[FindCharInString(sOutput, ',', true)] = 0;
							sOutput[FindCharInString(sOutput, ',', true)] = 0;

							if(StrEqual(sValue, sOutput))
								_Matches++;
						}
					}
					while(g_Config.GotoNextKey(false));

					g_Config.GoBack();
				}
				g_Config.GoBack();

				Matches += CalcMatches(_Matches, _ExactMatches, _MinMatches, _MaxMatches);
			}
			else if(StrEqual(sSection, "props"))
			{
				int _Matches = 0;
				int _ExactMatches = g_Config.GetNum("ExactMatches", -1);
				int _MinMatches = g_Config.GetNum("MinMatches", -1);
				int _MaxMatches = g_Config.GetNum("MaxMatches", -1);

				if(g_Config.GotoFirstSubKey(false))
				{
					do
					{
						g_Config.GetSectionName(sKey, sizeof(sKey));
						g_Config.GetString(NULL_STRING, sValue, sizeof(sValue));

						GetEntPropString(client, Prop_Data, sKey, sOutput, sizeof(sOutput));

						if(StrEqual(sValue, sOutput))
							_Matches++;
					}
					while(g_Config.GotoNextKey(false));

					g_Config.GoBack();
				}
				g_Config.GoBack();

				Matches += CalcMatches(_Matches, _ExactMatches, _MinMatches, _MaxMatches);
			}
			else if(StrEqual(sSection, "math"))
			{
				if(g_Config.GotoFirstSubKey(false))
				{
					do
					{
						g_Config.GetSectionName(sKey, sizeof(sKey));
						g_Config.GetString(NULL_STRING, sValue, sizeof(sValue));

						int Target = 0;
						int Input;
						int Parameter;

						Input = FindCharInString(sValue[Target], ',');
						sValue[Input] = 0; Input++;

						Parameter = Input + FindCharInString(sValue[Input], ',');
						sValue[Parameter] = 0; Parameter++;

						int Value = 0;
						int Count = GetOutputCount(client, sKey);
						for(int i = 0; i < Count; i++)
						{
							int _Target = 0;
							int _Input;
							int _Parameter;

							_Input = GetOutputTarget(client, sKey, i, sOutput[_Target], sizeof(sOutput) - _Target);
							sOutput[_Input] = 0; _Input++;

							_Parameter = _Input + GetOutputTargetInput(client, sKey, i, sOutput[_Input], sizeof(sOutput) - _Input);
							sOutput[_Parameter] = 0; _Parameter++;

							GetOutputParameter(client, sKey, i, sOutput[_Parameter], sizeof(sOutput) - _Parameter);

							if(!StrEqual(sOutput[_Target], sValue[Target]))
								continue;

							int _Value = StringToInt(sOutput[_Parameter]);

							if(StrEqual(sOutput[_Input], "add", false))
								Value += _Value;
							else if(StrEqual(sOutput[_Input], "subtract", false))
								Value -= _Value;
						}

						int Result = StringToInt(sValue[Parameter]);
						if(StrEqual(sValue[Input], "subtract", false))
							Result *= -1;

						if(Value == Result)
							Matches += 1;
					}
					while(g_Config.GotoNextKey(false));

					g_Config.GoBack();
				}
				g_Config.GoBack();
			}
		}
		while(g_Config.GotoNextKey(false));

		g_Config.GoBack();

		if(CalcMatches(Matches, ExactMatches, MinMatches, MaxMatches))
		{
			if(Found)
			{
				if(TargetsLen)
					StrCat(sTargets, TargetsLen, ";");
				if(NamesLen)
					StrCat(sNames, NamesLen, ", ");
			}

			Found = true;
			if(TargetsLen)
				StrCat(sTargets, TargetsLen, sTarget);
			if(NamesLen)
				StrCat(sNames, NamesLen, sName);
		}
	}
	while(g_Config.GotoNextKey());

	g_Config.Rewind();
	if(!Found)
		return false;
	return true;
}

public Action Command_Level(int client, int args)
{
	if(!g_Config)
	{
		ReplyToCommand(client, "[SM] The current map is not supported.");
		return Plugin_Handled;
	}

	if(args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_level <target> <level>");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	if((iTargetCount = ProcessTargetString(sTarget, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	char sLevel[32];
	GetCmdArg(2, sLevel, sizeof(sLevel));

	int Level;
	if(!StringToIntEx(sLevel, Level))
	{
		ReplyToCommand(client, "[SM] Level has to be a number.");
		return Plugin_Handled;
	}
	IntToString(Level, sLevel, sizeof(sLevel));

	g_Config.Rewind();
	if(!g_Config.JumpToKey("0"))
	{
		ReplyToCommand(client, "[SM] Setting levels on the current map is not supported.");
		return Plugin_Handled;
	}
	g_Config.GoBack();

	if(Level && !g_Config.JumpToKey(sLevel))
	{
		ReplyToCommand(client, "[SM] Level %s could not be found.", sLevel);
		return Plugin_Handled;
	}
	g_Config.Rewind();

	char sPrevNames[128];
	if(iTargetCount == 1)
		GetLevel(iTargets[0], sPrevNames, 0, sPrevNames, sizeof(sPrevNames));

	char sName[32];
	for(int i = 0; i < iTargetCount; i++)
	{
		// Reset level first
		if(Level)
		{
			if(!RestoreLevel(iTargets[i], "0"))
			{
				ReplyToCommand(client, "[SM] Failed resetting level on %L.", iTargets[i]);
				return Plugin_Handled;
			}
		}

		if(!RestoreLevel(iTargets[i], sLevel, sName, sizeof(sName)))
		{
			ReplyToCommand(client, "[SM] Failed setting level to %s on %L.", sLevel, iTargets[i]);
			return Plugin_Handled;
		}

		LogAction(client, iTargets[i], "Set %L to %s", iTargets[i], sName);
	}

	if(sPrevNames[0])
		ShowActivity2(client, "\x03[SaveLevel]\x01 ", "Set \x04%s\x01 from \x04%s\x01 to \x04%s\x01", sTargetName, sPrevNames, sName);
	else
		ShowActivity2(client, "\x03[SaveLevel]\x01 ", "Set \x04%s\x01 to \x04%s\x01", sTargetName, sName);

	return Plugin_Handled;
}

stock int CalcMatches(int Matches, int ExactMatches, int MinMatches, int MaxMatches)
{
	int Value = 0;
	if((ExactMatches == -1 && MinMatches == -1 && MaxMatches == -1 && Matches) ||
		Matches == ExactMatches ||
		(MinMatches != -1 && MaxMatches == -1 && Matches >= MinMatches) ||
		(MaxMatches != -1 && MinMatches == -1 && Matches <= MaxMatches) ||
		(MinMatches != -1 && MaxMatches != -1 && Matches >= MinMatches && Matches <= MaxMatches))
	{
		Value++;
	}

	return Value;
}
