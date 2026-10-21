#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>

#define PLUGIN_VERSION	"2.0.1"

#define CATEGORY	"nades"

KeyValues kv;
char sNadeMdl[MAXPLAYERS+1][PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "[Shop] Nades",
	author = "FrozDark (HLModders LLC)",
	description = "Nades component",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public void OnPluginStart()
{
	RegAdminCmd("nades_reload", Command_Reload, ADMFLAG_ROOT, "Reloads nades configuration");
	
	if (Shop_IsStarted()) Shop_Started();
}

public Action Command_Reload(int client, int args)
{
	OnPluginEnd();
	if (Shop_IsStarted()) Shop_Started();
	OnMapStart();
	ReplyToCommand(client, "Nades configuration successfuly reloaded!");
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	if (kv == null) OnMapStart();
	
	char buffer[64], desc[64];
	kv.GetString("name", buffer, sizeof(buffer));
	kv.GetString("description", desc, sizeof(desc));
	
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, buffer, desc);
	
	char item[64], model[PLATFORM_MAX_PATH];
	if (kv.GotoFirstSubKey())
	{
		do 
		{
			if (kv.GetSectionName(item, sizeof(item)))
			{
				kv.GetString("model", model, sizeof(model));
				int pos = FindCharInString(model, '.', true);
				if (pos != -1 && StrEqual(model[pos+1], "mdl", false) && Shop_StartItem(category_id, item))
				{
					kv.GetString("name", buffer, sizeof(buffer), item);
					kv.GetString("description", desc, sizeof(desc));
					
					Shop_SetInfo(buffer, desc, kv.GetNum("price", 5000), kv.GetNum("sell_price", 2500), Item_Togglable, kv.GetNum("duration", 86400));
					Shop_SetCallbacks(_, OnEquipItem);
					
					if (kv.JumpToKey("attributes"))
					{
						Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(kv));
						kv.GoBack();
					}
					
					Shop_SetCustomInfo("level", kv.GetNum("level", 0));
					Shop_EndItem();
					
					PrecacheModel(model, true);
				}
			}
		} while (kv.GotoNextKey());
	}
	
	kv.Rewind();
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	if (kv != null)
	{
		delete kv;
	}
	
	kv = new KeyValues("Nades");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "nades.txt");
	
	if (!kv.ImportFromFile(buffer))
	{
		SetFailState("Couldn't parse file %s", buffer);
	}
	kv.Rewind();
	if (kv.GotoFirstSubKey())
	{
		do
		{
			kv.GetString("model", buffer, sizeof(buffer));
			int pos = FindCharInString(buffer, '.', true);
			if (pos != -1 && StrEqual(buffer[pos+1], "mdl", false))
			{
				PrecacheModel(buffer, true);
			}
		} while (kv.GotoNextKey());
	}
	
	kv.Rewind();
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "nades_downloads.txt");
	File_ReadDownloadList(buffer);
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		sNadeMdl[client][0] = '\0';
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	if (kv.JumpToKey(item, false))
	{
		kv.GetString("model", sNadeMdl[client], sizeof(sNadeMdl[]));
		kv.Rewind();
		
		if (!sNadeMdl[client][0])
		{
			PrintToChat(client, "Failed to use \"%s\"!.", item);
			return Shop_Raw;
		}
		
		return Shop_UseOn;
	}
	
	PrintToChat(client, "Failed to use \"%s\"!.", item);
	
	return Shop_Raw;
}

public void OnClientDisconnect_Post(int client)
{
	sNadeMdl[client][0] = '\0';
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "hegrenade_projectile"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnHeSpawned);
	}
}

public void OnHeSpawned(int entity)
{
	if (GetEntProp(entity, Prop_Data, "m_nNextThinkTick") == -1)
	{
		return;
	}
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (0<client<=MaxClients && sNadeMdl[client][0])
	{
		SetEntityModel(entity, sNadeMdl[client]);
	}
}



char _smlib_empty_twodimstring_array[][] = { { '\0' } };
stock void File_AddToDownloadsTable(const char[] path, bool recursive=true, const char[][] ignoreExts=_smlib_empty_twodimstring_array, int size=0)
{
	if (path[0] == '\0') {
		return;
	}

	if (FileExists(path)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));
		
		if (StrEqual(fileExtension, "bz2", false) || StrEqual(fileExtension, "ztmp", false)) {
			return;
		}
		
		if (Array_FindString(ignoreExts, size, fileExtension) != -1) {
			return;
		}

		AddFileToDownloadsTable(path);
		
		if (StrEqual(fileExtension, "mdl", false))
		{
			PrecacheModel(path, true);
		}
	}
	
	else if (recursive && DirExists(path)) {

		char dirEntry[PLATFORM_MAX_PATH];
		DirectoryListing __dir = OpenDirectory(path);

		while (__dir.GetNext(dirEntry, sizeof(dirEntry))) {

			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
				continue;
			}
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		delete __dir;
	}
	else if (FindCharInString(path, '*', true)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			char dirName[PLATFORM_MAX_PATH], fileName[PLATFORM_MAX_PATH], dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			DirectoryListing __dir = OpenDirectory(dirName);
			while (__dir.GetNext(dirEntry, sizeof(dirEntry))) {

				if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
					continue;
				}

				if (strncmp(dirEntry, fileName, strlen(fileName)) == 0) {
					Format(dirEntry, sizeof(dirEntry), "%s/%s", dirName, dirEntry);
					File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
				}
			}

			delete __dir;
		}
	}

	return;
}

stock bool File_ReadDownloadList(const char[] path)
{
	File file = OpenFile(path, "r");
	
	if (file  == null) {
		return false;
	}

	char buffer[PLATFORM_MAX_PATH];
	while (!file.EndOfFile()) {
		file.ReadLine(buffer, sizeof(buffer));
		
		int pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		pos = StrContains(buffer, "#");
		if (pos != -1) {
			buffer[pos] = '\0';
		}

		pos = StrContains(buffer, ";");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		TrimString(buffer);
		
		if (buffer[0] == '\0') {
			continue;
		}

		File_AddToDownloadsTable(buffer);
	}

	delete file;
	
	return true;
}

stock void File_GetExtension(const char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock int Array_FindString(const char[][] array, int size, const char[] str, bool caseSensitive=true, int start=0)
{
	if (start < 0) {
		start = 0;
	}

	for (int i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}
	
	return -1;
}

stock void File_GetFileName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	int pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) {
		buffer[pos_ext] = '\0';
	}
}

stock void File_GetDirName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
		
		if (pos_start == -1) {
			buffer[0] = '\0';
			return;
		}
	}
	
	strcopy(buffer, size, path);
	buffer[pos_start] = '\0';
}

stock void File_GetBaseName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
	}
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}