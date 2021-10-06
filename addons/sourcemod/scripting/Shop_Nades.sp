#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>

#define PLUGIN_VERSION	"2.0.0"

#define CATEGORY	"nades"

new Handle:kv;
new String:sNadeMdl[MAXPLAYERS+1][PLATFORM_MAX_PATH];

public Plugin:myinfo =
{
	name = "[Shop] Nades",
	author = "FrozDark (HLModders LLC)",
	description = "Nades component",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public OnPluginStart()
{
	RegAdminCmd("nades_reload", Command_Reload, ADMFLAG_ROOT, "Reloads nades configuration");
	
	if (Shop_IsStarted()) Shop_Started();
}

public Action:Command_Reload(client, args)
{
	OnPluginEnd();
	if (Shop_IsStarted()) Shop_Started();
	OnMapStart();
	ReplyToCommand(client, "Nades configuration successfuly reloaded!");
	return Plugin_Handled;
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public Shop_Started()
{
	if (kv == INVALID_HANDLE) OnMapStart();
	
	decl String:buffer[64], String:desc[64];
	KvGetString(kv, "name", buffer, sizeof(buffer));
	KvGetString(kv, "description", desc, sizeof(desc));
	
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, buffer, desc);
	
	decl String:item[64], String:model[PLATFORM_MAX_PATH];
	if (KvGotoFirstSubKey(kv))
	{
		do 
		{
			if (KvGetSectionName(kv, item, sizeof(item)))
			{
				KvGetString(kv, "model", model, sizeof(model));
				new pos = FindCharInString(model, '.', true);
				if (pos != -1 && StrEqual(model[pos+1], "mdl", false) && Shop_StartItem(category_id, item))
				{
					KvGetString(kv, "name", buffer, sizeof(buffer), item);
					KvGetString(kv, "description", desc, sizeof(desc));
					
					Shop_SetInfo(buffer, desc, KvGetNum(kv, "price", 5000), KvGetNum(kv, "sell_price", 2500), Item_Togglable, KvGetNum(kv, "duration", 86400));
					Shop_SetCallbacks(_, OnEquipItem);
					
					if (KvJumpToKey(kv, "attributes"))
					{
						Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(kv));
						KvGoBack(kv);
					}
					
					Shop_SetCustomInfo("level", KvGetNum(kv, "level", 0));
					Shop_EndItem();
					
					PrecacheModel(model, true);
				}
			}
		} while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
}

public OnMapStart()
{
	decl String:buffer[PLATFORM_MAX_PATH];
	if (kv != INVALID_HANDLE)
	{
		CloseHandle(kv);
	}
	
	kv = CreateKeyValues("Nades");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "nades.txt");
	
	if (!FileToKeyValues(kv, buffer))
	{
		SetFailState("Couldn't parse file %s", buffer);
	}
	KvRewind(kv);
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetString(kv, "model", buffer, sizeof(buffer));
			new pos = FindCharInString(buffer, '.', true);
			if (pos != -1 && StrEqual(buffer[pos+1], "mdl", false))
			{
				PrecacheModel(buffer, true);
			}
		} while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "nades_downloads.txt");
	File_ReadDownloadList(buffer);
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		sNadeMdl[client][0] = '\0';
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	if (KvJumpToKey(kv, item, false))
	{
		KvGetString(kv, "model", sNadeMdl[client], sizeof(sNadeMdl[]));
		KvRewind(kv);
		
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

public OnClientDisconnect_Post(client)
{
	sNadeMdl[client][0] = '\0';
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!strcmp(classname, "hegrenade_projectile"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnHeSpawned);
	}
}

public OnHeSpawned(entity)
{
	if (GetEntProp(entity, Prop_Data, "m_nNextThinkTick") == -1)
	{
		return;
	}
	new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (0<client<=MaxClients && sNadeMdl[client][0])
	{
		SetEntityModel(entity, sNadeMdl[client]);
	}
}



new String:_smlib_empty_twodimstring_array[][] = { { '\0' } };
stock File_AddToDownloadsTable(const String:path[], bool:recursive=true, const String:ignoreExts[][]=_smlib_empty_twodimstring_array, size=0)
{
	if (path[0] == '\0') {
		return;
	}

	if (FileExists(path)) {
		
		decl String:fileExtension[4];
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

		decl String:dirEntry[PLATFORM_MAX_PATH];
		new Handle:__dir = OpenDirectory(path);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
				continue;
			}
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		CloseHandle(__dir);
	}
	else if (FindCharInString(path, '*', true)) {
		
		new String:fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			decl
				String:dirName[PLATFORM_MAX_PATH],
				String:fileName[PLATFORM_MAX_PATH],
				String:dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			new Handle:__dir = OpenDirectory(dirName);
			while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

				if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
					continue;
				}

				if (strncmp(dirEntry, fileName, strlen(fileName)) == 0) {
					Format(dirEntry, sizeof(dirEntry), "%s/%s", dirName, dirEntry);
					File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
				}
			}

			CloseHandle(__dir);
		}
	}

	return;
}

stock bool:File_ReadDownloadList(const String:path[])
{
	new Handle:file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) {
		return false;
	}

	new String:buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) {
		ReadFileLine(file, buffer, sizeof(buffer));
		
		new pos;
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

	CloseHandle(file);
	
	return true;
}

stock File_GetExtension(const String:path[], String:buffer[], size)
{
	new extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock Math_GetRandomInt(min, max)
{
	new random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock Array_FindString(const String:array[][], size, const String:str[], bool:caseSensitive=true, start=0)
{
	if (start < 0) {
		start = 0;
	}

	for (new i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}
	
	return -1;
}

stock bool:File_GetFileName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	new pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) {
		buffer[pos_ext] = '\0';
	}
}

stock bool:File_GetDirName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
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

stock bool:File_GetBaseName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
	}
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}