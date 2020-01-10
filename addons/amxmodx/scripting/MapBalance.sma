/**
*
* Name: MapBalance
* Version: 1.0 (10.01.2020)
* Author: BlackSignature
* Resource page: https://dev-cs.ru/resources/630/
* Description: This plugin allows you to automatically block certain areas on the map when
*	players count drops below specified value.
*
* Requirements: AMX Mod X 1.8.3 (or newer), ReAPI (optional)
*
* Thx to: s1lent, iG_os, mogel, medusa, Next21 Team, eryk172, chihuahuashka, wopox1337
*
* Changelog:
* 	0.1:
*		* Release
*	0.2:
*		* Fixed bug when mode roundtime not properly loaded if it < 1.0
*	0.3:
*		* Added bot support
*	0.4:
*		* Fixed initialization delay bug
*		* Added cvars:
*			* mb_cooldown_mode
*			* mb_state_cooldown
*			* mb_reanounce_cooldown
*	0.5:
*		* Major refactoring
*		* Some bugfixes
*		* API implementation
*		* New cvars:
*			* mb_manual_set_flags
*			* mb_allow_clcmds
*			* mb_combine_cooldowns
*	1.0:
*		* Fix grenades colliding with blocks (thx to wopox1337 & s1lent)
*		* Some bugfixes
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>
*
*/

new const PLUGIN_VERSION[] = "1.0"
new const PLUGIN_PREFIX[] = "[MB]"

#include <amxmodx>
#include <engine>
#include <xs>
#include <time>
#tryinclude <reapi>
#include <mapbalance>

/* ---------------------- НАСТРОЙКИ [НАЧАЛО] / TWEAKS [START] ---------------------- */

// Лимит объявляемых режимов / Modes limit
const MAX_MODES = 8

// Лимит бомбспотов, отключаемых в стандартном режиме игры
// Limit for bombspots, that can be disabled in default game mode
const MAX_BOMBSPOTS = 6

// Имя чат/консольной команды (без '/')
// Name of the say/console command (without '/')
new const CL_CMD[] = "modes"

// Имя консольной команды, позволяющей вручную задавать текущее значение игроков
// Name of the console command, with you can manually set current players number
new const PLAYERS_CMD[] = "mb_players"

// Флаг доступа к 'mb_players' по-умолчанию / Default 'mb_players' access flag
new const ACCESS_FLAG[] = "h"

new const MAIN_CONFIG_NAME[] = "MapBalance.cfg"
new const CFG_FOLDER_NAME[] = "MapBalance"
new const ERROR_LOG_NAME[] = "MapBalance_Errors.log"

/* ---------------------- НАСТРОЙКИ [КОНЕЦ] / TWEAKS [END] ---------------------- */

#define chx charsmax
#define chx_len(%0) charsmax(%0) - iLen

#if !defined MAX_MAPNAME_LENGTH
	#define MAX_MAPNAME_LENGTH 64
#endif

new const DUMMY_MODEL[] = "sprites/mapbalance_dummy.spr" //"models/gib_skull.mdl"
new const BLOCK_CLASSNAME[] = "mb_block"

const Float:PUSH_POWER = 64.0

enum { // states for cvar 'mb_hud_mode'
	HUD_MODE__OFF,
	HUD_MODE__HUD,
	HUD_MODE__DHUD
}

enum _:ELEMENT_MODE_ENUM { // do not break the order!
	MODE_SPAWN_TT,
	MODE_SPAWN_CT,
	MODE_BLOCK,
	MODE_MODEL,
	MODE_BUYZONE,
	MODE_BOMBSPOT,
	MODE_MODE
}

enum _:COOLDOWN_ENUM {
	COOLDOWN__STATE,
	COOLDOWN__REANOUNCE,
	COOLDOWN__CHANGE
}

enum { // states for cvar 'mb_init_mode'
	INIT_MODE__INSTANT,
	INIT_MODE__TIME,
	INIT_MODE__ROUNDS,
	INIT_MODE__RESTARTS
}

enum { // states for cvar 'mb_cooldown_mode'
	COOLDOWN_MODE__SECONDS = 1,
	COOLDOWN_MODE__ROUNDS
}

enum _:CVAR_ENUM {
	CVAR__INIT_MODE,
	CVAR__INIT_VALUE,
	CVAR__INIT_ANNOUNCE,
	CVAR__COOLDOWN_MODE,
	CVAR__STATE_COOLDOWN,
	CVAR__REANOUCE_COOLDOWN,
	CVAR__CHANGE_COOLDOWN,
	CVAR__USE_CHAT,
	CVAR__HUD_MODE,
	Float:CVAR_F__HUD_DURATION,
	// Do not break order ->
	CVAR__HUD_R_D,
	CVAR__HUD_G_D,
	CVAR__HUD_B_D,
	CVAR__HUD_R_C,
	CVAR__HUD_G_C,
	CVAR__HUD_B_C,
	// <-
	Float:CVAR_F__HUD_X,
	Float:CVAR_F__HUD_Y,
	CVAR__RESTORE_ROUNDTIME,
	CVAR__HL_MODELS,
	CVAR__ALLOW_CLCMDS,
	CVAR__COMBINE_COOLDOWNS
}

// TT: origin1 origin2 origin3 origin4 origin5 origin6 angleY modeid
enum _:spawn_args_enum { spawn_ident, spawn_def_origin_x, spawn_def_origin_y,
	spawn_def_origin_z,	spawn_new_origin_x, spawn_new_origin_y,
	spawn_new_origin_z, spawn_new_angle_y, spawn_mode_id };

// BLOCK: origin1 origin2 origin3 angleY size1 size2 size3 size4 size5 size6 modeid
enum _:block_args_enum { block_ident, block_origin_x, block_origin_y, block_origin_z,
	block_angle_y, block_mins_x, block_mins_y, block_mins_z, block_maxs_x,
	block_maxs_y, block_maxs_z, block_mode_id }	;

// MDL: modelid origin1 origin2 origin3 angle1 angle2 angle3 scale sequence frame framerate
// rendermode renderfx renderamt rendercolor1 rendercolor2 rendercolor3 modeid
enum _:model_args_enum { mdl_ident, mdl_id, mdl_origin_x, mdl_origin_y,	mdl_origin_z,
	mdl_angle_x, mdl_angle_y, mdl_angle_z, mdl_scale, mdl_sequence, mdl_frame,
	mdl_framerate, mdl_rendermode, mdl_renderfx, mdl_renderamt, mdl_redercolor_r,
	mdl_rendercolor_g, mdl_rendercolor_b, mdl_mode_id };

// BUYZONE: teamid origin1 origin2 origin3 size1 size2 size3 size4 size5 size6 modeid
enum _:buyzone_args_enum { bz_ident, bz_teamid, bz_origin_x, bz_origin_y, bz_origin_z,
	bz_mins_x, bz_mins_y, bz_mins_z, bz_maxs_x, bz_maxs_y, bz_maxs_z, bz_mode_id };

// BOMBSPOT: origin1 origin2 origin3 modeid
enum _:bombspot_args_enum { bmb_ident, bmb_origin_x, bmb_origin_y, bmb_origin_z, bmb_mode_id }

// MODE: "text" players roundtime colorid suffix
enum _:mode_args_enum { mode_ident, mode_text, mode_players, mode_roundtime, mode_color, mode_suffix }

new g_eCvar[CVAR_ENUM]
new g_eModeData[MODE_DATA_STRUCT]
new g_eSpawnData[SPAWN_DATA_STRUCT]
new g_eElementData[ELEMENT_DATA_STUCT]
new g_szCfgFile[PLATFORM_MAX_PATH]
new g_iModelsCount
new g_pRoundTime
new g_iModeCount
new g_iCurrentMode
new g_iCurrCyclePlCnt
new g_pDisDefBombSpots[MAX_BOMBSPOTS]
new g_iDisDefCount
new Float:g_fDefaultRoundTime
new g_szErrorLog[PLATFORM_MAX_PATH]
new Array:g_aModels
new Array:g_aModeData
new Array:g_aSpawnData[MAX_MODES]
new Array:g_aElementData[MAX_MODES]
new g_pUser
new g_szMapName[MAX_MAPNAME_LENGTH]
new g_hHudSyncObj
new g_iRRs
new g_iForcedPls = INVALID_HANDLE
new g_iRealPls
new g_iRoundCounter = 1
new Float:g_fLastTime[COOLDOWN_ENUM]
new g_iLastRound[COOLDOWN_ENUM]
new g_iCmdAccessFlags
new bool:g_bMainCfgLoaded
new g_fwdOnModelCfgLoad
new g_fwdOnMainCfgLoad
new g_fwdOnSystemInit
new g_fwdOnNewRoundEvent
new g_fwdOnModeChange
new bool:g_bSystemInit
new Float:g_fInitJobTime

/****************************************************************************************
************************************* INITIALIZATION ************************************
****************************************************************************************/

public plugin_precache() {
	register_plugin("MapBalance", PLUGIN_VERSION, "BlackSignature")
	register_dictionary("MapBalance.txt")

	func_RegisterCvars()

	/* --- */

	new iLen = get_localinfo("amxx_logs", g_szErrorLog, chx(g_szErrorLog))
	formatex(g_szErrorLog[iLen], chx_len(g_szErrorLog), "/%s", ERROR_LOG_NAME)

	/* --- */

	new szPath[PLATFORM_MAX_PATH]

	iLen = get_localinfo("amxx_configsdir", szPath, chx(szPath))
	formatex(szPath[iLen], chx_len(szPath), "/%s", MAIN_CONFIG_NAME)
	server_cmd("exec %s", szPath)
	server_exec()

	/* --- */

	g_fwdOnModelCfgLoad = CreateMultiForward( "MapBalance_OnModelCfgLoad", ET_CONTINUE,
		FP_CELL, FP_CELL, FP_CELL, FP_CELL );

	g_fwdOnMainCfgLoad = CreateMultiForward( "MapBalance_OnMainCfgLoad", ET_CONTINUE,
		FP_CELL, FP_CELL, FP_CELL );

	g_fwdOnSystemInit = CreateMultiForward("MapBalance_OnSystemInit", ET_CONTINUE, FP_CELL)

	g_fwdOnNewRoundEvent = CreateMultiForward( "MapBalance_OnNewRoundEvent", ET_CONTINUE,
		FP_CELL, FP_CELL, FP_CELL, FP_CELL );

	g_fwdOnModeChange = CreateMultiForward("MapBalance_OnModeChange", ET_IGNORE, FP_CELL)

	/* --- */

	iLen += formatex(szPath[iLen], chx_len(szPath), "/%s", CFG_FOLDER_NAME)

	get_mapname(g_szMapName, chx(g_szMapName))
	formatex(g_szCfgFile, chx(g_szCfgFile), "%s/%s.ini", szPath, g_szMapName)

	new bool:bMainCfgFound = bool:file_exists(g_szCfgFile)

	new iRet; ExecuteForward(g_fwdOnModelCfgLoad, iRet, FORWARD_CALL__PRE, RESULT_CODE__NOT_SET, 0, bMainCfgFound)

	if(iRet == FORWARD_RETURN__STOP) {
		return
	}

	if(bMainCfgFound) {
		func_LoadModels(szPath, iLen)
	}
	else {
		ExecuteForward(g_fwdOnModelCfgLoad, iRet, FORWARD_CALL__POST, RESULT_CODE__FAIL, 0, false)
	}
}

/* -------------------- */

func_LoadModels(szPath[PLATFORM_MAX_PATH], iLen) {
	if(!file_exists(DUMMY_MODEL)) {
		set_fail_state("Can't find '%s'", DUMMY_MODEL)
	}

	precache_model(DUMMY_MODEL)

	formatex(szPath[iLen], chx_len(szPath), "/%s-models.ini", g_szMapName)
	new hFile = fopen(szPath, "r")

	if(!hFile) {
		new iResultCode = RESULT_CODE__FAIL

		if(file_exists(szPath)) {
			iResultCode = RESULT_CODE__ERROR
			func_InitError()
			log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", szPath)
		}

		formatex(szPath[iLen], chx_len(szPath), "/default_models.ini")

		hFile = fopen(szPath, "r")

		if(!hFile) {
			if(file_exists(szPath)) {
				iResultCode = RESULT_CODE__ERROR
				func_InitError()
				log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", szPath)
			}

			ExecuteForward(g_fwdOnModelCfgLoad, _, FORWARD_CALL__POST, iResultCode, 0, true)
			return
		}
	}

	g_aModels = ArrayCreate(MAX_MODEL_PATH_LENGTH, 1)

	new szText[128], szNum[3], szModel[MAX_MODEL_PATH_LENGTH], iNumPos, iLine

	while(!feof(hFile)) {
		iLine++; fgets(hFile, szText, chx(szText))

		switch(szText[0]) {
			case ';', '/', '^n': {
				continue
			}
		}

		if(!isdigit(szText[0])) {
			func_InitError()
			log_to_file(g_szErrorLog, "[MDLCFG] %L", LANG_SERVER, "MB__CANT_RECOGNIZE_STRING", iLine)
			continue
		}

		parse(szText, szNum, chx(szNum), szModel, chx(szModel))

		iNumPos = str_to_num(szNum)

		if(iNumPos - g_iModelsCount != 1) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
				LANG_SERVER, "MB__WRONG_MDL_ENUM", iNumPos, g_iModelsCount );

			continue
		}

		if(!g_eCvar[CVAR__HL_MODELS] && !file_exists(szModel)) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
				LANG_SERVER, "MB__MDL_NOT_FOUND", szModel );

			continue
		}

		precache_model(szModel)

		ArrayPushString(g_aModels, szModel)
		g_iModelsCount++
	}

	fclose(hFile)

	ExecuteForward(g_fwdOnModelCfgLoad, _, FORWARD_CALL__POST, RESULT_CODE__OK, g_iModelsCount, true)
}

/* -------------------- */

public plugin_cfg() {
	g_hHudSyncObj = CreateHudSyncObj()
}

/* -------------------- */

public OnConfigsExecuted() {
	new const szPrefix[][] = { "say /", "say_team /"/*, "say .", "say_team ."*/ }

	new szCmd[48]

	for(new i; i < sizeof(szPrefix); i++) {
		formatex(szCmd, chx(szCmd), "%s%s", szPrefix[i], CL_CMD)
		register_clcmd(szCmd, "clcmd_ShowModesInChat")
	}

	register_clcmd(CL_CMD, "clcmd_ShowModesInConsole")

	register_concmd(PLAYERS_CMD, "concmd_SetPlayers")

	/* --- */

	register_event("HLTV", "event_NewRound", "a", "1=0", "2=0")
	register_event("TextMsg", "event_RoundRestart", "a", "2&#Game_will")

	if(!g_bMainCfgLoaded) {
		func_LoadMainCfg()
		func_SetInitJob()
	}
}

/****************************************************************************************
******************************** LOADING 'MAP_NAME.INI' *********************************
****************************************************************************************/

func_LoadMainCfg() {
	g_bMainCfgLoaded = true

	new bool:bMainCfgFound = bool:file_exists(g_szCfgFile)

	new iRet; ExecuteForward(g_fwdOnMainCfgLoad, iRet, FORWARD_CALL__PRE, RESULT_CODE__NOT_SET, bMainCfgFound)

	if(iRet == FORWARD_RETURN__STOP) {
		return
	}

	/* --- */

	if(!bMainCfgFound) {
		ExecuteForward(g_fwdOnMainCfgLoad, _, FORWARD_CALL__POST, RESULT_CODE__FAIL, false)
		return
	}

	/* --- */

	new hFile = fopen(g_szCfgFile, "r")

	if(!hFile) {
		func_InitError()
		log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", g_szCfgFile)
		ExecuteForward(g_fwdOnMainCfgLoad, _, FORWARD_CALL__POST, RESULT_CODE__ERROR, true)
		return
	}

	const MAX_ARG_COUNT = model_args_enum // NOTE: must be equal to enum value with the greater elements count
	const PERMANENT_MODE = '0'

	new const iArgCount[ELEMENT_MODE_ENUM] = {
		spawn_args_enum,
		spawn_args_enum,
		block_args_enum,
		model_args_enum,
		buyzone_args_enum,
		bombspot_args_enum,
		mode_args_enum
	}

	new szArgument[MAX_ARG_COUNT][32], iModeID, pEnt, i, Float:fColor[XYZ],
		iLastPlayerNum, iCycleFirstMode = INVALID_HANDLE, bool:bHaveBlocks, iSpawnLinkCount[TEAM_ENUM];

	new iLine, szText[256], Float:fOrigin[XYZ], Float:fAngles[XYZ], Float:fMins[XYZ],
		Float:fMaxs[XYZ], iModelID, szModel[MAX_MODEL_PATH_LENGTH], iPlCount;

	new szModeName[MAX_MODE_NAME_LENGTH]

	g_aModeData = ArrayCreate(MODE_DATA_STRUCT, 1)

	if(!g_pRoundTime) {
		g_pRoundTime = get_cvar_pointer("mp_roundtime")
	}
	else {
		arrayset(g_eModeData, 0, sizeof(g_eModeData))
	}

	g_fDefaultRoundTime = get_pcvar_float(g_pRoundTime)

	g_eModeData[ROUND_TIME] = g_fDefaultRoundTime
	func_FmtRoundTimeString(g_fDefaultRoundTime, g_eModeData[ROUND_TIME_STR], ROUND_TIME_LENGTH - 1)
	formatex(g_eModeData[CHAT_DESC], MAX_MODE_NAME_LENGTH - 1, "%L", LANG_SERVER, "MB__ALL_MAP_CHAT")
	formatex(g_eModeData[HUD_DESC], MAX_MODE_NAME_LENGTH - 1, "%L", LANG_SERVER, "MB__ALL_MAP_HUD")
	ArrayPushArray(g_aModeData, g_eModeData)

	while(!feof(hFile))	{
		iLine++; fgets(hFile, szText, chx(szText))
		trim(szText)

		switch(szText[0]) {
			case 'T': {
				iModeID = MODE_SPAWN_TT
			}
			case 'C': {
				iModeID = MODE_SPAWN_CT
			}
			case 'M': {
				iModeID = szText[1] == 'O' ? MODE_MODE : MODE_MODEL;
			}
			case 'B': {
				switch(szText[1]) {
					case 'L': {
						iModeID = MODE_BLOCK
					}
					case 'U': {
						iModeID = MODE_BUYZONE
					}
					default: { // 'O'
						iModeID = MODE_BOMBSPOT
					}
				}
			}
			case ';', '/', EOS: {
				continue
			}
			default: {
				func_InitError()
				log_to_file(g_szErrorLog, "[MAPCFG] %L", LANG_SERVER, "MB__CANT_RECOGNIZE_STRING", iLine)
				continue
			}
		}

		new iParsePos, iCurrArg, iTextLen = strlen(szText)

		while(iParsePos != iTextLen) {
			if(iCurrArg == MAX_ARG_COUNT) {
				func_InitError()

				log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
					LANG_SERVER, "MB__ARG_LIMIT_EXCEEEDED", MAX_ARG_COUNT );

				iModeID = INVALID_HANDLE
				break
			}

			iParsePos = argparse(szText, iParsePos, szArgument[iCurrArg++], chx(szArgument[]))
		}

		if(iModeID == INVALID_HANDLE) {
			continue
		}

		if(iCurrArg != iArgCount[iModeID]) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
				LANG_SERVER, "MB__WRONG_ARG_COUNT", iCurrArg, iArgCount[iModeID] );

			continue
		}

		switch(iModeID) {
			case MODE_SPAWN_TT, MODE_SPAWN_CT: {
				for(i = 0, iCurrArg = spawn_def_origin_x; i < XYZ; i++) {
					g_eSpawnData[DEFAULT_ORIGIN][i] = str_to_float(szArgument[iCurrArg++])
				}

				for(i = 0, iCurrArg = spawn_new_origin_x; i < XYZ; i++) {
					g_eSpawnData[MODIFIED_ORIGIN][i] = str_to_float(szArgument[iCurrArg++])
				}

				g_eSpawnData[MODIFIED_ANGLE] = str_to_float(szArgument[spawn_new_angle_y])
				g_eSpawnData[TEAM_ID] = iModeID

				iSpawnLinkCount[iModeID] += func_LinkElement(iModeID, 0, szArgument[spawn_mode_id], iLine)
			}
			case MODE_BLOCK: {
				pEnt = func_CreateElement("info_target", ELEMENT_BLOCK, iLine)

				if(!pEnt) {
					continue
				}

				entity_set_string(pEnt, EV_SZ_classname, BLOCK_CLASSNAME)

				// TODO will fix grenade penetration
				//ArrayGetString(g_aModels, 0, szModel, chx(szModel))
				//entity_set_model(pEnt, szModel)

				entity_set_model(pEnt, DUMMY_MODEL)

				for(i = 0, iCurrArg = block_origin_x; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_origin(pEnt, fOrigin)

				fAngles[X] = fAngles[Z] = 0.0
				fAngles[Y] = str_to_float(szArgument[block_angle_y])
				entity_set_vector(pEnt, EV_VEC_angles, fAngles)

				entity_set_int(pEnt, EV_INT_movetype, MOVETYPE_FLY)

				for(i = 0, iCurrArg = block_mins_x; i < XYZ; i++) {
					fMins[i] = str_to_float(szArgument[iCurrArg++])
				}

				for(i = 0, iCurrArg = block_maxs_x; i < XYZ; i++) {
					fMaxs[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_size(pEnt, fMins, fMaxs)

				set_entity_visibility(pEnt, .visible = 0)

				if(szArgument[block_mode_id][0] != PERMANENT_MODE) {
					if(func_LinkElement(MODE_BLOCK, pEnt, szArgument[block_mode_id], iLine)) {
						bHaveBlocks = true
					}
				}
				else {
					entity_set_int(pEnt, EV_INT_solid, SOLID_BBOX)
					bHaveBlocks = true
				}
			}
			case MODE_MODEL: {
				iModelID = str_to_num(szArgument[mdl_id])

				if(iModelID < 1 || iModelID > g_iModelsCount) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
						LANG_SERVER, "MB__WRONG_MODEL_ID", iModelID, g_iModelsCount ? 1 : 0, g_iModelsCount );

					continue
				}

				pEnt = func_CreateElement("env_sprite", ELEMENT_MODEL, iLine)

				if(!pEnt) {
					continue
				}

				ArrayGetString(g_aModels, iModelID - 1, szModel, chx(szModel))
				entity_set_model(pEnt, szModel)

				entity_set_float(pEnt, EV_FL_framerate, 1.0)
				DispatchSpawn(pEnt)

				for(i = 0, iCurrArg = mdl_origin_x; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_origin(pEnt, fOrigin)

				for(i = 0, iCurrArg = mdl_angle_x; i < XYZ; i++) {
					fAngles[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_vector(pEnt, EV_VEC_angles, fAngles)

				entity_set_float(pEnt, EV_FL_scale, str_to_float(szArgument[mdl_scale]))
				entity_set_int(pEnt, EV_INT_sequence, str_to_num(szArgument[mdl_sequence]))
				entity_set_float(pEnt, EV_FL_frame, str_to_float(szArgument[mdl_frame]))
				entity_set_float(pEnt, EV_FL_framerate, str_to_float(szArgument[mdl_framerate]))
				entity_set_int(pEnt, EV_INT_rendermode, str_to_num(szArgument[mdl_rendermode]))
				entity_set_int(pEnt, EV_INT_renderfx, str_to_num(szArgument[mdl_renderfx]))
				entity_set_float(pEnt, EV_FL_renderamt, str_to_float(szArgument[mdl_renderamt]))

				for(i = 0, iCurrArg = mdl_redercolor_r; i < RGB; i++) {
					fColor[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_vector(pEnt, EV_VEC_rendercolor, fColor)

				if(szArgument[mdl_mode_id][0] != PERMANENT_MODE) {
					set_entity_visibility(pEnt, .visible = 0)
					func_LinkElement(MODE_MODEL, pEnt, szArgument[mdl_mode_id], iLine)
				}
			}
			case MODE_BUYZONE: {
				new iTeamID

				switch(szArgument[bz_teamid][0]) {
					case 'T': {
						iTeamID = TEAMID_TT
					}
					case 'C': {
						iTeamID = TEAMID_CT
					}
					default: {
						func_InitError()

						log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
							LANG_SERVER, "MB__WRONG_TEAM_ID", szArgument[bz_teamid] );

						continue
					}
				}

				pEnt = func_CreateElement("func_buyzone", ELEMENT_BUYZONE, iLine)

				if(!pEnt) {
					continue
				}

				DispatchKeyValue(pEnt, "team", iTeamID ? "2" : "1")
				DispatchSpawn(pEnt)

				for(i = 0, iCurrArg = bz_origin_x; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_origin(pEnt, fOrigin)

				for(i = 0, iCurrArg = bz_mins_x; i < XYZ; i++) {
					fMins[i] = str_to_float(szArgument[iCurrArg++])
				}

				for(i = 0, iCurrArg = bz_maxs_x; i < XYZ; i++) {
					fMaxs[i] = str_to_float(szArgument[iCurrArg++])
				}

				entity_set_size(pEnt, fMins, fMaxs)

				if(szArgument[bz_mode_id][0] != PERMANENT_MODE) {
					entity_set_int(pEnt, EV_INT_solid, SOLID_NOT)
					func_LinkElement(MODE_BUYZONE, pEnt, szArgument[bz_mode_id], iLine)
				}
			}
			case MODE_BOMBSPOT: {
				for(i = 0, iCurrArg = bmb_origin_x; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szArgument[iCurrArg++])
				}

				new Float:fEntOrigin[XYZ]
				pEnt = MaxClients

				while((pEnt = find_ent_by_class(pEnt, "func_bomb_target"))) {
					entity_get_vector(pEnt, EV_VEC_origin, fEntOrigin)

					if(!fEntOrigin[X] && !fEntOrigin[Y] && !fEntOrigin[X]) {
						new Float:fMins[XYZ], Float:fMaxs[XYZ]

						entity_get_vector(pEnt, EV_VEC_mins, fMins)
						entity_get_vector(pEnt, EV_VEC_maxs, fMaxs)

						fEntOrigin[X] = (fMins[X] + fMaxs[X]) * 0.5
						fEntOrigin[Y] = (fMins[Y] + fMaxs[Y]) * 0.5
						fEntOrigin[Z] = (fMins[Z] + fMaxs[Z]) * 0.5
					}

					if(fOrigin[X] == fEntOrigin[X] && fOrigin[Y] == fEntOrigin[Y] && fOrigin[Z] == fEntOrigin[Z]) {
						break
					}
				}

				if(pEnt) {
					if(szArgument[bmb_mode_id][0] == PERMANENT_MODE) {
						entity_set_int(pEnt, EV_INT_solid, SOLID_NOT)
						continue
					}

					new iPos

					if(szArgument[bmb_mode_id][0] == '-' && szArgument[bmb_mode_id][1] == '1') {
						if(g_iDisDefCount == MAX_BOMBSPOTS) {
							func_InitError()

							log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
								LANG_SERVER, "MB__BOMBSPOT_LIMIT_REACHED" );
						}
						else {
							entity_set_int(pEnt, EV_INT_solid, SOLID_NOT)
							g_pDisDefBombSpots[g_iDisDefCount++] = pEnt
						}

						if(!szArgument[bmb_mode_id][2]) {
							continue
						}

						iPos = 3
					}
					else {
						iPos = 0
					}

					func_LinkElement(iModeID, pEnt, szArgument[bmb_mode_id][iPos], iLine)
					continue
				}

				func_InitError()

				log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
					LANG_SERVER, "MB__BOMBSPOT_NOT_FOUND", fOrigin[X], fOrigin[Y], fOrigin[Z] );
			}
			case MODE_MODE: {
				if(g_iModeCount == MAX_MODES) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
						LANG_SERVER, "MB__MODE_LIMIT_REACHED" );

					continue
				}

				iPlCount = str_to_num(szArgument[mode_players])

				if(iPlCount < 1 || iPlCount < iLastPlayerNum) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
						LANG_SERVER, "MB__WRONG_PLAYERS_NUM", iPlCount, iLastPlayerNum );

					continue
				}

				if(iPlCount == iLastPlayerNum) {
					if(iCycleFirstMode == INVALID_HANDLE) {
						iCycleFirstMode = g_iModeCount
					}

					ArrayGetArray(g_aModeData, g_iModeCount, g_eModeData)
					g_eModeData[NEXT_MODE] = g_iModeCount + 1
					ArraySetArray(g_aModeData, g_iModeCount, g_eModeData)

					g_eModeData[NEXT_MODE] = iCycleFirstMode
				}
				else {
					g_eModeData[NEXT_MODE] = iCycleFirstMode = INVALID_HANDLE
				}

				g_aSpawnData[g_iModeCount] = ArrayCreate(SPAWN_DATA_STRUCT, 1)
				g_aElementData[g_iModeCount++] = ArrayCreate(ELEMENT_DATA_STUCT, 1)

				g_eModeData[PLAYER_COUNT] = iLastPlayerNum = iPlCount

				parse(szText, "", "", szModeName, chx(szModeName))
				replace_string(szModeName, chx(szModeName), "!n", "^1")
				replace_string(szModeName, chx(szModeName), "!t", "^3")
				replace_string(szModeName, chx(szModeName), "!g", "^4")
				g_eModeData[CHAT_DESC] = szModeName

				func_RemoveColor(szModeName, chx(szModeName))
				g_eModeData[HUD_DESC] = szModeName

				// 0.2 version fix
				/*g_eModeData[ROUND_TIME] = (szArgument[mode_roundtime][0] == '0') ?
					g_fDefaultRoundTime : str_to_float(szArgument[mode_roundtime]);*/

				g_eModeData[ROUND_TIME] = str_to_float(szArgument[mode_roundtime])

				if(!g_eModeData[ROUND_TIME]) {
					g_eModeData[ROUND_TIME] = g_fDefaultRoundTime
				}

				func_FmtRoundTimeString(g_eModeData[ROUND_TIME], g_eModeData[ROUND_TIME_STR], ROUND_TIME_LENGTH - 1)

				new iColor

				switch(szArgument[mode_color][0]) {
					case 'd': iColor = print_team_default
					case 'w': iColor = print_team_grey
					case 'r': iColor = print_team_red
					case 'b': iColor = print_team_blue
					default: {
						iColor = print_team_default
						func_InitError()

						log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
							LANG_SERVER, "MB__WRONG_COLOR_ID", szArgument[mode_color] );
					}
				}

				g_eModeData[CHAT_COLOR] = iColor

			#if defined _reapi_included
				if(szArgument[mode_suffix][0]) {
					formatex( g_eModeData[MAP_NAME], chx(g_eModeData[MAP_NAME]), "%s%s",
						g_szMapName, szArgument[mode_suffix] );
				}
				else {
					g_eModeData[MAP_NAME][0] = EOS
				}
			#endif
				ArrayPushArray(g_aModeData, g_eModeData)
			}
		}
	}

	fclose(hFile)

	/*******************************************************************************************/
	/*********************** COMPARING SPAWNS FROM CONFIG WITH MAP SPAWNS **********************/
	/*******************************************************************************************/

	if(iSpawnLinkCount[TEAMID_TT] || iSpawnLinkCount[TEAMID_CT]) {
		new const szEntClassName[TEAM_ENUM][] = { "info_player_deathmatch", "info_player_start" }

		new a, b

		for(i = 0; i < TEAM_ENUM; i++) {
			pEnt = MaxClients

			while(iSpawnLinkCount[i] && (pEnt = find_ent_by_class(pEnt, szEntClassName[i])))	{
				entity_get_vector(pEnt, EV_VEC_origin, fOrigin)

				for(a = 0; a < g_iModeCount; a++) {
					ArrayGetArray(g_aModeData, a + 1, g_eModeData)

					for(b = 0; b < g_eModeData[SPAWN_COUNT]; b++) {
						ArrayGetArray(g_aSpawnData[a], b, g_eSpawnData)

						if(
							g_eSpawnData[TEAM_ID] != i
								||
							g_eSpawnData[DEFAULT_ORIGIN][X] != fOrigin[X]
								||
							g_eSpawnData[DEFAULT_ORIGIN][Y] != fOrigin[Y]
								||
							g_eSpawnData[DEFAULT_ORIGIN][Z] != fOrigin[Z]
						) {
							continue
						}

						entity_get_vector(pEnt, EV_VEC_angles, fAngles)
						g_eSpawnData[DEFAULT_ANGLE] = fAngles[Y]
						g_eSpawnData[SPAWN_ID] = pEnt
						ArraySetArray(g_aSpawnData[a], b, g_eSpawnData)
						iSpawnLinkCount[i]--
						break
					}
				}
			}
		}

		new iCount = iSpawnLinkCount[TEAMID_TT] + iSpawnLinkCount[TEAMID_CT]

		if(iCount) {
			for(i = b = 0; i < g_iModeCount; i++) {
				ArrayGetArray(g_aModeData, i + 1, g_eModeData)

				for(a = 0; a < g_eModeData[SPAWN_COUNT]; a++) {
					ArrayGetArray(g_aSpawnData[i], a, g_eSpawnData)

					if(!g_eSpawnData[SPAWN_ID])	{
						func_InitError()

						log_to_file( g_szErrorLog, "%L [%i]", LANG_SERVER, "MB__SPAWN_NOT_FOUND",
							g_eSpawnData[TEAM_ID] ? "CT" : "TT", g_eSpawnData[DEFAULT_ORIGIN][X],
							g_eSpawnData[DEFAULT_ORIGIN][Y], g_eSpawnData[DEFAULT_ORIGIN][Z], i + 1 );

						g_eModeData[SPAWN_COUNT]--
						ArrayDeleteItem(g_aSpawnData[i], a--)

						if(++b == iCount) {
							break
						}
					}
				}

				ArraySetArray(g_aModeData, i + 1, g_eModeData)

				if(b == iCount) {
					break
				}
			}
		}
	}

	/*******************************************************************************************/
	/******************************** FINAL INITIALIZATION PART ********************************/
	/*******************************************************************************************/

	static hTouch

	if(bHaveBlocks && !hTouch) {
		hTouch = register_touch("weaponbox", BLOCK_CLASSNAME, "OnTouch_Pre")
	}

	ExecuteForward(g_fwdOnMainCfgLoad, _, FORWARD_CALL__POST, RESULT_CODE__OK, true)
}

/* -------------------- */

func_SetInitJob() {
	g_fInitJobTime = get_gametime()
	g_iRoundCounter = 1
	g_iRRs = 0

	if(!g_iModeCount || g_eCvar[CVAR__INIT_MODE] == INIT_MODE__INSTANT) {
		func_InitSystem()
	}
}

/* -------------------- */

bool:func_TryInitSystem() {
	switch(g_eCvar[CVAR__INIT_MODE]) {
		/* case INIT_MODE__INSTANT: {
			// nothing here
		} */
		case INIT_MODE__TIME: {
			if(get_gametime() < g_fInitJobTime + float(g_eCvar[CVAR__INIT_VALUE])) {
				return false
			}
		}
		case INIT_MODE__ROUNDS: {
			if(g_iRoundCounter <= g_eCvar[CVAR__INIT_VALUE]) {
				return false
			}
		}
		case INIT_MODE__RESTARTS: {
			if(g_iRRs < g_eCvar[CVAR__INIT_VALUE]) {
				return false
			}
		}
	}

	return func_InitSystem()
}

/* -------------------- */

bool:func_InitSystem() {
	new iRet; ExecuteForward(g_fwdOnSystemInit, iRet, FORWARD_CALL__PRE)

	if(iRet == FORWARD_RETURN__STOP) {
		return false
	}

	g_bSystemInit = true

	if(g_eCvar[CVAR__INIT_ANNOUNCE]) {
		client_print_color(0, print_team_red, "^4%s ^3%L", PLUGIN_PREFIX, LANG_PLAYER, "MB__SYSTEM_INITIALIZED")
	}

	ExecuteForward(g_fwdOnSystemInit, _, FORWARD_CALL__POST)
	return true
}

/* -------------------- */

func_LinkElement(iMode, pEnt, szBuffer[], iLine) {
	new iParsePos, iModeIndex, iBindCount, szArg[3], iTextLen = strlen(szBuffer)

	while(iParsePos != iTextLen) {
		iParsePos = argparse(szBuffer, iParsePos, szArg, chx(szArg))

		iModeIndex = str_to_num(szArg)

		if(iModeIndex < 1 || iModeIndex > g_iModeCount) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
				LANG_SERVER, "MB__CANT_BIND_TO_UNDEFINED_MODE", iModeIndex );

			continue
		}

		iBindCount++
		ArrayGetArray(g_aModeData, iModeIndex, g_eModeData)

		if(iMode > MODE_SPAWN_CT) {
			g_eModeData[ELEMENT_COUNT]++
			g_eElementData[ELEMENT_TYPE] = iMode
			g_eElementData[ELEMENT_ID] = pEnt
			ArrayPushArray(g_aElementData[iModeIndex - 1], g_eElementData)
		}
		else {
			g_eModeData[SPAWN_COUNT]++
			ArrayPushArray(g_aSpawnData[iModeIndex - 1], g_eSpawnData)
		}

		ArraySetArray(g_aModeData, iModeIndex, g_eModeData)
	}

	return iBindCount
}

/****************************************************************************************
*********************************** MAP MODE CHANGING ***********************************
****************************************************************************************/

public event_NewRound() {
	g_iRoundCounter++

	if((!g_bSystemInit && !func_TryInitSystem()) || !g_iModeCount) {
		return PLUGIN_CONTINUE
	}

	/* --- */

	new iModeToSet, iPlayers, iRet

	g_iRealPls = func_GetPlayersInGame()

	ExecuteForward(g_fwdOnNewRoundEvent, iRet, FORWARD_CALL__PRE, g_iCurrentMode, g_iRealPls, g_iForcedPls)

	if(iRet == FORWARD_RETURN__STOP) {
		return PLUGIN_CONTINUE
	}

	ExecuteForward(g_fwdOnNewRoundEvent, iRet, FORWARD_CALL__POST, g_iCurrentMode, g_iRealPls, g_iForcedPls)

	if(g_iForcedPls == INVALID_HANDLE) {
		iPlayers = g_iRealPls
	}
	else {
		iPlayers = g_iForcedPls
	}

	for(new i = 1; i <= g_iModeCount; i++) {
		ArrayGetArray(g_aModeData, i, g_eModeData)

		// That's the reason why modes need to be defined from min to max players
		if(iPlayers > g_eModeData[PLAYER_COUNT])
			continue

		iModeToSet = i
		break
	}

	if(g_iCurrentMode) { // If one of the modes is active
		if(!iModeToSet) { // If current player count > players each of the modes
			if(IsInCooldown(COOLDOWN__STATE)) {
				return func_TryReanounce()
			}
			// else ->
			func_SetMode(g_iCurrentMode, .bEnable = false, .bFinal = true)
			func_ToggleBombSpots(SOLID_NOT)
			return PLUGIN_CONTINUE
		}

		if(IsInCooldown(g_eCvar[CVAR__COMBINE_COOLDOWNS] ? COOLDOWN__STATE : COOLDOWN__CHANGE)) {
			return func_TryReanounce()
		}

		// If current mode is cycled, and mode to set is the first mode of that cycle
		if(g_iCurrCyclePlCnt == g_eModeData[PLAYER_COUNT]) {
			/* First call to func_SetMode() will execute ArrayGetArray() for g_iCurrentMode,
			that's how we know what mode is the next mode in the cycle */
			func_SetMode(g_iCurrentMode, .bEnable = false, .bFinal = false)
			return func_SetMode(g_eModeData[NEXT_MODE], .bEnable = true, .bFinal = true)
		}

		if(iModeToSet != g_iCurrentMode) { // If mode to set is not current mode
			func_SetMode(g_iCurrentMode, .bEnable = false, .bFinal = false)
			return func_SetMode(iModeToSet, .bEnable = true, .bFinal = true)
		}

		return func_TryReanounce() // Mode to set is already active, and not cycled
	}

	// If no modes is active, and...

	if(iModeToSet && !IsInCooldown(COOLDOWN__STATE)) { // ...one of the modes was set to activation
		func_ToggleBombSpots(SOLID_TRIGGER)
		return func_SetMode(iModeToSet, .bEnable = true, .bFinal = true)
	}

	return func_TryReanounce() // ...no modes was set to activation
}

/* -------------------- */

bool:IsInCooldown(iCdPtr) {
	static const iCvarPtr[COOLDOWN_ENUM] = { CVAR__STATE_COOLDOWN, CVAR__REANOUCE_COOLDOWN, CVAR__CHANGE_COOLDOWN }

	new iPtr = iCvarPtr[iCdPtr]

	if(g_eCvar[CVAR__COOLDOWN_MODE] == COOLDOWN_MODE__SECONDS) {
		new Float:fCurrTime = get_gametime()
		new Float:fCoolDown = float(g_eCvar[iPtr])

		if(g_fLastTime[iCdPtr] && fCurrTime - g_fLastTime[iCdPtr] < fCoolDown) {
			return true
		}

		g_fLastTime[iCdPtr] = fCurrTime
		return false
	}

	// else COOLDOWN_MODE__ROUNDS ->

	new iCoolDown = g_eCvar[iPtr]

	if(g_iLastRound[iCdPtr] && g_iRoundCounter - g_iLastRound[iCdPtr] < iCoolDown) {
		return true
	}

	g_iLastRound[iCdPtr] = g_iRoundCounter
	return false
}

/* -------------------- */

func_TryReanounce() {
	if(IsInCooldown(COOLDOWN__REANOUNCE)) {
		return PLUGIN_CONTINUE
	}

	return func_SendInfo()
}

/* -------------------- */

func_SetMode(iMode, bool:bEnable, bool:bFinal, bool:bSendInfo = true) {
	ArrayGetArray(g_aModeData, iMode, g_eModeData)

	new pEnt, Float:fOrigin[XYZ], Float:fAngles[XYZ]

	for(new i; i < g_eModeData[SPAWN_COUNT]; i++) {
		ArrayGetArray(g_aSpawnData[iMode - 1], i, g_eSpawnData)

		pEnt = g_eSpawnData[SPAWN_ID]

		if(bEnable) {
			fOrigin[X] = Float:g_eSpawnData[MODIFIED_ORIGIN][X]
			fOrigin[Y] = Float:g_eSpawnData[MODIFIED_ORIGIN][Y]
			fOrigin[Z] = Float:g_eSpawnData[MODIFIED_ORIGIN][Z]
		}
		else {
			fOrigin[X] = Float:g_eSpawnData[DEFAULT_ORIGIN][X]
			fOrigin[Y] = Float:g_eSpawnData[DEFAULT_ORIGIN][Y]
			fOrigin[Z] = Float:g_eSpawnData[DEFAULT_ORIGIN][Z]
		}

		entity_set_origin(pEnt, fOrigin)
		fAngles[Y] = Float:g_eSpawnData[bEnable ? MODIFIED_ANGLE : DEFAULT_ANGLE]
		entity_set_vector(pEnt, EV_VEC_angles, fAngles)
	}

	for(new i; i < g_eModeData[ELEMENT_COUNT]; i++) {
		ArrayGetArray(g_aElementData[iMode - 1], i, g_eElementData)
		pEnt = g_eElementData[ELEMENT_ID]

		switch(g_eElementData[ELEMENT_TYPE]) {
			case MODE_BLOCK: entity_set_int(pEnt, EV_INT_solid, bEnable ? SOLID_BBOX : SOLID_NOT)
			case MODE_BUYZONE: entity_set_int(pEnt, EV_INT_solid, bEnable ? SOLID_TRIGGER : SOLID_NOT)
			case MODE_MODEL: set_entity_visibility(pEnt, .visible = bEnable ? 1 : 0)
			case MODE_BOMBSPOT:	entity_set_int(pEnt, EV_INT_solid, bEnable ? SOLID_NOT : SOLID_TRIGGER)
		}
	}

	if(bFinal) {
		g_iCurrentMode = bEnable ? iMode : 0;
		g_iCurrCyclePlCnt = (g_eModeData[NEXT_MODE] == INVALID_HANDLE) ? 0 : g_eModeData[PLAYER_COUNT];

		if(bSendInfo) {
			func_SendInfo()
		}

		set_pcvar_float(g_pRoundTime, bEnable ? g_eModeData[ROUND_TIME] : g_fDefaultRoundTime)

	#if defined _reapi_included
		static bool:bCustomMapName

		if(!g_eModeData[MAP_NAME][0]) {
			if(bCustomMapName) {
				rh_reset_mapname()
				bCustomMapName = false
			}

			return func_ExecModeFwd(bFinal)
		}

		rh_set_mapname(g_eModeData[MAP_NAME])
		bCustomMapName = true
	#endif
	}

	return func_ExecModeFwd(bFinal)
}

/* -------------------- */

func_ExecModeFwd(bool:bFinal) {
	if(bFinal) {
		ExecuteForward(g_fwdOnModeChange, _, g_iCurrentMode)
	}

	return PLUGIN_CONTINUE
}

/* -------------------- */

func_SendInfo() {
	ArrayGetArray(g_aModeData, g_iCurrentMode, g_eModeData)

	if(g_eCvar[CVAR__HUD_MODE]) {
		set_task(0.1, "task_ShowHUD")
	}

	if(g_eCvar[CVAR__USE_CHAT]) {
		client_print_color( 0, g_eModeData[CHAT_COLOR], "^4%s ^1%L", PLUGIN_PREFIX, LANG_PLAYER,
			"MB__MODE_ANNOUNCE", g_iRealPls, g_eModeData[CHAT_DESC], g_eModeData[ROUND_TIME_STR] );
	}

	g_fLastTime[COOLDOWN__REANOUNCE] = get_gametime()
	g_iLastRound[COOLDOWN__REANOUNCE] = g_iRoundCounter

	return PLUGIN_CONTINUE
}

/* -------------------- */

public task_ShowHUD() {
	new iColor[RGB], iPtr = (g_iCurrentMode ? CVAR__HUD_R_C : CVAR__HUD_R_D)

	for(new i; i < RGB; i++) {
		iColor[i] = g_eCvar[iPtr++]
	}

	if(g_eCvar[CVAR__HUD_MODE] == HUD_MODE__HUD) {
		set_hudmessage( iColor[R], iColor[G], iColor[B], g_eCvar[CVAR_F__HUD_X], g_eCvar[CVAR_F__HUD_Y],
			0, 0.0, g_eCvar[CVAR_F__HUD_DURATION], 0.1, 0.1, -1 );

		ShowSyncHudMsg(0, g_hHudSyncObj, "%L %s", LANG_PLAYER, "MB__GAME_MODE", g_eModeData[HUD_DESC])

		return
	}

	// HUD_MODE__DHUD ->

	set_dhudmessage( iColor[R], iColor[G], iColor[B], g_eCvar[CVAR_F__HUD_X], g_eCvar[CVAR_F__HUD_Y],
		0, 0.0, g_eCvar[CVAR_F__HUD_DURATION], 0.1, 0.1 );

	show_dhudmessage(0, "%L %s", LANG_PLAYER, "MB__GAME_MODE", g_eModeData[HUD_DESC])
}

/****************************************************************************************
*************************************** MISCALEOUS **************************************
****************************************************************************************/

public OnTouch_Pre(pTouched, pToucher) {
	if(is_valid_ent(pTouched) && is_valid_ent(pToucher)) {
		new Float:fAngles[XYZ], Float:fVelocity[XYZ]

		entity_get_vector(pToucher, EV_VEC_angles, fAngles)
		angle_vector(fAngles, ANGLEVECTOR_FORWARD, fVelocity)

		xs_vec_mul_scalar(fVelocity, PUSH_POWER, fVelocity)

		/*fVelocity[X] *= PUSH_POWER
		fVelocity[Y] *= PUSH_POWER
		fVelocity[Z] *= PUSH_POWER*/

		entity_set_vector(pTouched, EV_VEC_velocity, fVelocity)
	}
}

/* -------------------- */

public clcmd_ShowModesInChat(id) {
	if(!g_eCvar[CVAR__ALLOW_CLCMDS]) {
		return PLUGIN_HANDLED
	}

	if(g_iModeCount) {
		if(g_iModeCount > 4) {
			client_print_color(id, print_team_red, "^4* ^1%L", id, "MB__USE_CON_CMD")
			return PLUGIN_HANDLED
		}

		for(new i = 1; i <= g_iModeCount; i++) {
			ArrayGetArray(g_aModeData, i, g_eModeData)

			client_print_color( id, g_eModeData[CHAT_COLOR], "^4* ^1%L", id, "MB__CHAT_MODE_INFO",
				g_eModeData[CHAT_DESC], g_eModeData[ROUND_TIME_STR], g_eModeData[PLAYER_COUNT] );
		}

		return PLUGIN_HANDLED
	}

	client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__NO_MODES_CHAT")
	return PLUGIN_HANDLED
}


/* -------------------- */

public clcmd_ShowModesInConsole(pPlayer) {
	if(!g_eCvar[CVAR__ALLOW_CLCMDS]) {
		return PLUGIN_HANDLED
	}

	console_print(pPlayer, " ")

	if(g_iModeCount) {
		for(new i = 1; i <= g_iModeCount; i++) {
			ArrayGetArray(g_aModeData, i, g_eModeData)

			engclient_print( pPlayer, engprint_console, "%s %l", PLUGIN_PREFIX, "MB__CON_MODE_INFO",
				g_eModeData[CHAT_DESC], g_eModeData[ROUND_TIME_STR], g_eModeData[PLAYER_COUNT] );
		}
	}
	else {
		console_print(pPlayer, "%s %l", PLUGIN_PREFIX, "MB__NO_MODES_CON")
	}

	console_print(pPlayer, " ")
	return PLUGIN_HANDLED
}

/* -------------------- */

func_InitError() {
	static bool:bInitError

	if(!bInitError) {
		bInitError = true
		log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__INIT_ERROR", g_szMapName)
	}
}

/* -------------------- */

func_CreateElement(const szClassName[], iElementType, iLine) {
	new pEnt = create_entity(szClassName)

	if(!pEnt) {
		func_InitError()

		log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", iLine,
			LANG_SERVER, "MB__CANT_SET_ELEMENT", LANG_SERVER, "MB__CREATE_S",
			LANG_SERVER, fmt("MB__ELEMENT_%i", iElementType + 1) );
	}

	return pEnt
}

/* -------------------- */

func_RemoveColor(szBuffer[], iMaxLen) {
	replace_string(szBuffer, iMaxLen, "^1", "")
	replace_string(szBuffer, iMaxLen, "^3", "")
	replace_string(szBuffer, iMaxLen, "^4", "")
}

/* -------------------- */

func_ToggleBombSpots(iSolidState) {
	if(g_iDisDefCount) {
		for(new i; i < g_iDisDefCount; i++) {
			entity_set_int(g_pDisDefBombSpots[i], EV_INT_solid, iSolidState)
		}
	}
}

/* -------------------- */

func_FmtRoundTimeString(Float:fTime, szBuffer[], iMaxLen) {
	new iSec, iMin = (iSec = floatround(floatmul(fTime, 60.0))) / SECONDS_IN_MINUTE
	iSec = max(0, (iSec -= (iMin * SECONDS_IN_MINUTE)))
	formatex(szBuffer, iMaxLen, "%i:%02d", iMin, iSec)
}

/* -------------------- */

func_GetPlayersInGame() {
	new pPlayers[MAX_PLAYERS], iPlCount, iInGame
	get_players(pPlayers, iPlCount, "h")

	for(new i; i < iPlCount; i++) {
		if(IsPlayerInGame(pPlayers[i])) {
			iInGame++
		}
	}

	return iInGame
}

/* -------------------- */

bool:IsPlayerInGame(pPlayer) {
#if defined _reapi_included
	return (TEAM_SPECTATOR > get_member(pPlayer, m_iTeam) > TEAM_UNASSIGNED)
#else
	return (3 > get_user_team(pPlayer) > 0)
#endif
}

/* -------------------- */

public event_RoundRestart() {
	static Float:fLastTime

	new Float:fGameTime = get_gametime()

	if(fLastTime == fGameTime) {
		return
	}

	fLastTime = fGameTime

	g_iRRs++
}

/* -------------------- */

public concmd_SetPlayers(pPlayer) {
	if(~get_user_flags(pPlayer) & g_iCmdAccessFlags) {
		return PLUGIN_HANDLED
	}

	if(read_argc() == 1) {
		if(pPlayer) {
			console_print(pPlayer, "%s %L: %s #", PLUGIN_PREFIX, pPlayer, "MB__CMD_USAGE", PLAYERS_CMD)
		}
		else {
			console_print(pPlayer, "%s Usage: %s #", PLUGIN_PREFIX, PLAYERS_CMD)
		}

		return PLUGIN_HANDLED
	}

	new szVal[3]; read_argv(1, szVal, chx(szVal))

	g_iForcedPls = clamp(str_to_num(szVal), INVALID_HANDLE, MAX_PLAYERS)

	if(pPlayer) {
		console_print(pPlayer, "%s %L '%i'", PLUGIN_PREFIX, pPlayer, "MB__YOU_ENTER", g_iForcedPls)
	}
	else {
		console_print(pPlayer, "%s You enter '%i'", PLUGIN_PREFIX, g_iForcedPls)
	}

	new szName[MAX_NAME_LENGTH]
	get_user_name(pPlayer, szName, chx(szName))

	if(g_iForcedPls == INVALID_HANDLE) {
		g_pUser = 0

		client_print_color( 0, print_team_red, "^4%s ^3%L", PLUGIN_PREFIX,
			LANG_PLAYER, "MB__FORCE_RESET_MANUAL", szName );

		return PLUGIN_HANDLED
	}

	g_pUser = pPlayer
	client_print_color(0, print_team_red, "^4%s ^3%L", PLUGIN_PREFIX, LANG_PLAYER, "MB__FORCE_SET", szName)
	return PLUGIN_HANDLED
}

/* -------------------- */

public client_disconnected(pPlayer) {
	if(g_pUser != pPlayer) {
		return
	}

	g_pUser = 0
	g_iForcedPls = INVALID_HANDLE
	client_print_color(0, print_team_red, "^4%s ^3%L", PLUGIN_PREFIX, LANG_PLAYER, "MB__FORCE_RESET_AUTO")
}

/* -------------------- */

func_RegisterCvars() {
	bind_pcvar_num( create_cvar( "mb_init_mode", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 3.0 ),
		g_eCvar[CVAR__INIT_MODE] );

	bind_pcvar_num( create_cvar( "mb_init_value", "20",
			.has_min = true, .min_val = 1.0 ),
		g_eCvar[CVAR__INIT_VALUE] );

	bind_pcvar_num(create_cvar("mb_init_announce", "1"), g_eCvar[CVAR__INIT_ANNOUNCE])

	bind_pcvar_num( create_cvar( "mb_cooldown_mode", "1",
			.has_min = true, .min_val = 1.0,
			.has_max = true, .max_val = 2.0 ),
		g_eCvar[CVAR__COOLDOWN_MODE] );

	bind_pcvar_num(create_cvar( "mb_state_cooldown", "10" ), g_eCvar[CVAR__STATE_COOLDOWN])
	bind_pcvar_num(create_cvar( "mb_reanounce_cooldown", "10" ), g_eCvar[CVAR__REANOUCE_COOLDOWN])
	bind_pcvar_num(create_cvar( "mb_change_cooldown", "10"), g_eCvar[CVAR__CHANGE_COOLDOWN])
	bind_pcvar_num(create_cvar("mb_combine_cooldowns", "1"), g_eCvar[CVAR__COMBINE_COOLDOWNS])
	bind_pcvar_num(create_cvar("mb_use_chat", "1"), g_eCvar[CVAR__USE_CHAT])

	bind_pcvar_num( create_cvar( "mb_hud_mode", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 2.0 ),
		g_eCvar[CVAR__HUD_MODE] );

	bind_pcvar_float( create_cvar( "mb_hud_duration", "5",
			.has_min = true, .min_val = 1.0 ),
		g_eCvar[CVAR_F__HUD_DURATION] );

	bind_pcvar_num( create_cvar( "mb_hud_r_default", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_R_D] );

	bind_pcvar_num( create_cvar( "mb_hud_g_default", "200",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_G_D] );

	bind_pcvar_num( create_cvar( "mb_hud_b_default", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_B_D] );

	bind_pcvar_num( create_cvar( "mb_hud_r_custom", "200",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_R_C] );

	bind_pcvar_num( create_cvar( "mb_hud_g_custom", "200",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_G_C] );

	bind_pcvar_num( create_cvar( "mb_hud_b_custom", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 255.0 ),
		g_eCvar[CVAR__HUD_B_C] );

	bind_pcvar_float(create_cvar("mb_hud_x", "-1.0"), g_eCvar[CVAR_F__HUD_X])
	bind_pcvar_float(create_cvar("mb_hud_y", "0.31"), g_eCvar[CVAR_F__HUD_Y])
	bind_pcvar_num(create_cvar("mb_restore_roundtime", "1"), g_eCvar[CVAR__RESTORE_ROUNDTIME])
	bind_pcvar_num(create_cvar("mb_hl_models", "0"), g_eCvar[CVAR__HL_MODELS])

	new pCvar = create_cvar("mb_manual_set_flags", ACCESS_FLAG)
	new szFlags[32]; get_pcvar_string(pCvar, szFlags, chx(szFlags))
	g_iCmdAccessFlags = read_flags(szFlags)
	hook_cvar_change(pCvar, "hook_CvarChange")

	bind_pcvar_num(create_cvar("mb_allow_clcmds", "1"), g_eCvar[CVAR__ALLOW_CLCMDS])

	create_cvar("MapBalance", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
}

/* -------------------- */

public hook_CvarChange(pCvar, szOldVal[], szNewVal[]) {
	g_iCmdAccessFlags = read_flags(szNewVal)
}

/* -------------------- */

public plugin_end() {
	if(g_aModels) {
		ArrayDestroy(g_aModels)
	}

	if(g_aModeData)	{
		if(g_eCvar[CVAR__RESTORE_ROUNDTIME] && g_fDefaultRoundTime) {
			set_pcvar_float(g_pRoundTime, g_fDefaultRoundTime)
		}

		ArrayDestroy(g_aModeData)

		for(new i; i < g_iModeCount; i++) {
			ArrayDestroy(g_aSpawnData[i])
			ArrayDestroy(g_aElementData[i])
		}
	}
}

/* -------------------- */

public plugin_natives() {
	register_native("MapBalance_ReloadMainCfg", "_MapBalance_ReloadMainCfg")
	register_native("MapBalance_GetInitState", "_MapBalance_GetInitState")
	register_native("MapBalance_SetInitState", "_MapBalance_SetInitState")
	register_native("MapBalance_GetModelsArrayHandle", "_MapBalance_GetModelsArrayHandle")
	register_native("MapBalance_GetModelCount", "_MapBalance_GetModelCount")
	register_native("MapBalance_GetMainArrayHandle", "_MapBalance_GetMainArrayHandle")
	register_native("MapBalance_GetModeCount", "_MapBalance_GetModeCount")
	register_native("MapBalance_GetSpawnArrayHandle", "_MapBalance_GetSpawnArrayHandle")
	register_native("MapBalance_GetElementArrayHandle", "_MapBalance_GetElementArrayHandle")
	register_native("MapBalance_FormatMainCfgPath", "_MapBalance_FormatMainCfgPath")
	register_native("MapBalance_GetCurrentMode", "_MapBalance_GetCurrentMode")
	register_native("MapBalance_SetCurrentMode", "_MapBalance_SetCurrentMode")
	register_native("MapBalance_GetForcedPlayersCount", "_MapBalance_GetForcedPlayersCount")
	register_native("MapBalance_SetForcedPlayersCount", "_MapBalance_SetForcedPlayersCount")
}

/* -------------------- */

public _MapBalance_ReloadMainCfg(iPluginID, iParamCount) {
	if(g_aModeData) {
		if(g_iCurrentMode) {
			func_SetMode(g_iCurrentMode, .bEnable = false, .bFinal = true, .bSendInfo = false)
			g_iCurrentMode = 0
		}

		new pEnt

		for(new i; i < g_iModeCount; i++) {
			ArrayDestroy(g_aSpawnData[i])
			g_aSpawnData[i] = Invalid_Array

			ArrayGetArray(g_aModeData, i + 1, g_eModeData)

			for(new a; a < g_eModeData[ELEMENT_COUNT]; a++) {
				ArrayGetArray(g_aElementData[i], a, g_eElementData)

				if(g_eElementData[ELEMENT_TYPE] == MODE_BOMBSPOT) {
					continue
				}

				pEnt = g_eElementData[ELEMENT_ID]

				if(is_valid_ent(pEnt)) {
					remove_entity(pEnt)
				}
			}

			ArrayDestroy(g_aElementData[i])
			g_aElementData[i] = Invalid_Array
		}

		ArrayDestroy(g_aModeData)
		g_aModeData = Invalid_Array
		g_iModeCount = 0
	}

	g_iCurrCyclePlCnt = 0

	if(g_iDisDefCount) {
		func_ToggleBombSpots(SOLID_TRIGGER)
		g_iDisDefCount = 0
		arrayset(g_pDisDefBombSpots, 0, sizeof(g_pDisDefBombSpots))
	}

	/* --- */

	func_LoadMainCfg()
	g_bSystemInit = true
}

/* -------------------- */

public bool:_MapBalance_GetInitState(iPluginID, iParamCount) {
	return g_bSystemInit
}

/* -------------------- */

public _MapBalance_SetInitState(iPluginID, iParamCount) {
	enum { system_state = 1, reaply_init_job };

	g_bSystemInit = bool:get_param(system_state)

	if(!g_bSystemInit && get_param(reaply_init_job)) {
		func_SetInitJob()
	}
}

/* -------------------- */

public Array:_MapBalance_GetModelsArrayHandle(iPluginID, iParamCount) {
	return g_aModels
}

/* -------------------- */

public _MapBalance_GetModelCount(iPluginID, iParamCount) {
	return g_iModelsCount
}

/* -------------------- */

public Array:_MapBalance_GetMainArrayHandle(iPluginID, iParamCount) {
	return g_aModeData
}

/* -------------------- */

public _MapBalance_GetModeCount(iPluginID, iParamCount) {
	return g_iModeCount
}

/* -------------------- */

public Array:_MapBalance_GetSpawnArrayHandle(iPluginID, iParamCount) {
	enum { mode_id = 1 }

	new iModeID = get_param(mode_id)

	if(iModeID < 1 || iModeID > g_iModeCount) {
		return Invalid_Array
	}

	return g_aSpawnData[iModeID - 1]
}

/* -------------------- */

public Array:_MapBalance_GetElementArrayHandle(iPluginID, iParamCount) {
	enum { mode_id = 1 }

	new iModeID = get_param(mode_id)

	if(iModeID < 1 || iModeID > g_iModeCount) {
		return Invalid_Array
	}

	return g_aElementData[iModeID - 1]
}

/* -------------------- */

public bool:_MapBalance_FormatMainCfgPath(iPluginID, iParamCount) {
	enum { cfg_name = 1 }

	new szCfgName[MAX_CONFIG_FILENAME]
	get_string(cfg_name, szCfgName, chx(szCfgName))

	new iLen = get_localinfo("amxx_configsdir", g_szCfgFile, chx(g_szCfgFile))
	iLen += formatex(g_szCfgFile[iLen], chx_len(g_szCfgFile), "/%s", CFG_FOLDER_NAME)
	formatex(g_szCfgFile[iLen], chx_len(g_szCfgFile), "/%s.ini", szCfgName)

	return bool:file_exists(g_szCfgFile)
}

/* -------------------- */

public _MapBalance_GetCurrentMode(iPluginID, iParamCount) {
	return g_iCurrentMode
}

/* -------------------- */

public _MapBalance_SetCurrentMode(iPluginID, iParamCount) {
	enum { mode_id = 1, annouce_info }

	new iModeToSet = get_param(mode_id)

	if(iModeToSet < 0 || iModeToSet > g_iModeCount || iModeToSet == g_iCurrentMode) {
		return false
	}

	new bool:bSendInfo = bool:get_param(annouce_info)

	if(g_iCurrentMode) {
		func_SetMode(g_iCurrentMode, .bEnable = false, .bFinal = iModeToSet ? false : true, .bSendInfo = bSendInfo)
	}

	if(iModeToSet) {
		func_SetMode(iModeToSet, .bEnable = true, .bFinal = true, .bSendInfo = bSendInfo)
	}

	return true
}

/* -------------------- */

public _MapBalance_GetForcedPlayersCount(iPluginID, iParamCount) {
	return g_iForcedPls
}

/* -------------------- */

public _MapBalance_SetForcedPlayersCount(iPluginID, iParamCount) {
	enum { pl_count = 1 }
	g_iForcedPls = clamp(get_param(pl_count), INVALID_HANDLE, MAX_PLAYERS)
}