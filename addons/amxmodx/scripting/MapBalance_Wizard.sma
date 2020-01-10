/* Requirements:
	* AMX Mod X 1.8.3, or newer
*/

/* Credists:
	Used code and ideas:
		"Mode 2x2" by s1lent
		"Map Spawns Editor" by iG_os
		"WalkGuard" by mogel
	Special thx to:
		Next21 Team
		medusa for sprites pack: https://dev-cs.ru/threads/180/post-7523
*/

/* Changelog:
	0.1:
		* Release
	0.2:
		* Now when activating noclip, player recieves speed boost
		* Added 'disable safe range check' as option for spawns menu
	0.3:
		* Fixed wrong cvar bind for 'mb_hud_y'
	0.4:
		* Added wrong player count message (mlkey MB_WRONG_PLCOUNT_VALUE)
		* Log error handler refactoring
		* Some bugfixes
*/

new const PLUGIN_NAME[] = "MapBalance Wizard"
new const PLUGIN_VERSION[] = "0.4"
new const PLUGIN_AUTHOR[] = "mx?!"
new const PLUGIN_PREFIX[] = "[MBW]"

#include <amxmodx>
#include <engine>
#include <xs>
#include <time>

/* ---------------------- НАСТРОЙКИ / TWEAKS [НАЧАЛО / START] ---------------------- */

// "h" - Флаг доступа к меню по-умолчанию / Default menu access flag
new ACCESS_FLAG = ADMIN_CFG

// Лимит объявляемых режимов / Modes limit
const MAX_MODES = 8

// Имя консольной команды меню / Name of menu console command
new const MENU_CONCMD[] = "mbw_menu"

new const CFG_PREFIX[] = "wizard__"
new const CFG_FOLDER_NAME[] = "MapBalance"
new const ERROR_LOG_NAME[] = "MBW-ERROR-LOG.log"
new const MENU_TITLE_PREFIX[] = "\d[\rMBW\d]"

/* ---------------------- НАСТРОЙКИ / TWEAKS [КОНЕЦ / END] ---------------------- */

#define chx charsmax

enum { _KEY1_, _KEY2_, _KEY3_, _KEY4_, _KEY5_, _KEY6_, _KEY7_, _KEY8_, _KEY9_, _KEY0_ }
enum _:XYZ { Float:X, Float:Y, Float:Z }
enum _:RGB { R, G, B }

new const FOPEN_WRITE[] = "w"
new const FOPEN_READ[] = "r"

const _D_ = 'd'
const _W_ = 'w'

new const INFO_TARGET[] = "info_target"
new const FUNC_BUYZONE[] = "func_buyzone"
new const ENV_SPRITE[] = "env_sprite"
new const FUNC_BOMB_TARGET[] = "func_bomb_target"

new const MENU_IDENT_STRING__MBW[] = "MBW Menu"

new const SOUND__BLIP1[] = "buttons/blip1.wav"
new const SOUND__ERROR[] = "buttons/button2.wav"

const Float:PLAYER_CENTER_HEIGHT = 36.0

const Float:MAX_ANGLE = 360.0

const ALL_KEYS = 1023

#define MAPNAME_LEN 32
#define MENU_LEN 512
#define BIG_STRING_LEN 256
#define BIG_BUFF_LEN 64
#define SM_BUFF_LEN 32
#define ROUND_TIME_LEN 7
#define POSTFIX_LEN 8

#define SET_VISIBLE true
#define SET_INVISIBLE false

/* --- */

new const SPAWN_MODEL[][] = { "models/player/leet/leet.mdl", "models/player/gign/gign.mdl",
	"models/player/arctic/arctic.mdl", "models/player/vip/vip.mdl" }

new const BLOCK_MODEL[] = "models/gib_skull.mdl"
new const UNSAFE_BEAM_SPRITE[] = "sprites/laserbeam.spr"
new const BOX_LINE_SPRITE[] = "sprites/dot.spr"

const PLAYER_SEQUENCE_UNLINKED = 1
const PLAYER_SEQUENCE_LINKED = 64

enum _:COLORS_ENUM { COLOR_GREEN, COLOR_YELLOW, COLOR_RED }
new const Float:GLOW_COLOR[COLORS_ENUM][XYZ] = { { 0.0, 255.0, 0.0 }, { 200.0, 200.0, 0.0 }, { 255.0, 0.0, 0.0 } }

const UNSAFE_BEAM_BRIGHTNESS = 255
new const UNSAFE_BEAM_COLOR[RGB] = { 255, 0, 0 }

new const Float:BLOCK_MINS[XYZ] = { -32.0, -32.0, -32.0 }
new const Float:BLOCK_MAXS[XYZ] = { 32.0, 32.0, 32.0 }
new const Float:BUYZONE_MINS[XYZ] = { -32.0, -32.0, -32.0 }
new const Float:BUYZONE_MAXS[XYZ] = { 32.0, 32.0, 32.0 }

const BOX_LINE_WIDTH = 5
const BOX_LINE_BRIGHTNESS = 200
new const BOX_LINE_COLOR_MAIN[RGB] = { 0, 255, 0 }
new const BOX_LINE_COLOR_RED[RGB] = { 255, 0, 0 }
new const BOX_LINE_COLOR_YELLOW[RGB] = { 255, 255, 0 }

const Float:STRONG_PUSH	= 64.0

const Float:DEFAULT_SCALE = 1.0
const Float:DEFAULT_RENDERAMT = 255.0

const Float:NORMAL_OFFSET = 10.0
const Float:ABOVE_OFFSET = 115.0

const Float:SAFEp2w = 40.0
const Float:SAFEp2p = 85.0

new const NO_VALUE[] = "\d~"

new const MBW_SPAWN_CLASSNAME[] = "mbw_spawn"
new const MBW_BLOCK_CLASSNAME[] = "mbw_block"

new const BZ_TEAM_KEY[] = "team"

const TASKID__BOX_LINES = 666

#define ENTVAR__MDL_ID_TO_LINK EV_INT_iuser1
#define ENTVAR__IS_DEFAULT_SPAWN EV_INT_iuser1
#define ENTVAR__LINKED_SPAWN_ID EV_INT_iuser2
#define ENTVAR__POS_IN_DYNARRAY EV_INT_iuser3
#define ENTVAR__BUYZONE_TEAM_ID EV_INT_iuser2

#define INITIALIZE__FULL true
#define INITIALIZE__WITHOUT_SPAWNS false

#define ELEMENT_INFO__REMOVE false

#define TBO__MODELS true
#define TBO__SOLID false

enum { MENUTYPE__MAIN_MENU, MENUTYPE__MODE_MENU, MENUTYPE__MODE_SUBMENU, MENUTYPE__SPAWN_MENU, MENUTYPE__BLOCK_MENU,
	MENUTYPE__BLOCK_SUBMENU, MENUTYPE__MODEL_MENU, MENUTYPE__MODEL_SUBMENU_1, MENUTYPE__MODEL_SUBMENU_2,
	MENUTYPE__BUYZONE_MENU, MENUTYPE__BUYZONE_SUBMENU, MENUTYPE__BOMBSPOT_MENU }

enum { PROMTMODE__MDL_VAR_SCALE, PROMTMODE__MDL_VAR_SEQUENCE, PROMTMODE__MDL_VAR_FRAME, PROMTMODE__MDL_VAR_FRAMERATE,
	PROMTMODE__MDL_VAR_RENDERMODE, PROMTMODE__MDL_VAR_RENDERFX, PROMTMODE__MDL_VAR_RENDERAMT,
	PROMTMODE__MDL_VAR_RENDERCOLOR, PROMTMODE__MODE_BIND, PROMTMODE__SET_MODE_PLAYERS, PROMTMODE__SET_MODE_NAME,
	PROMTMODE__SET_MODE_COLOR, PROMTMODE__SET_MODE_ROUND_TIME, PROMTMODE__SET_MODE_POSTFIX, DELETE_MODE }

enum { ERRORID__SOMETHING_WRONG, ERRORID__PRECACHE_IS_EMPTY, ERRORID__NO_BOMBSPOTS, ERRORID__CANT_WRITE_TO_CFG,
	ERRORID__UNBINDED_ELEMENT_DETECTED, ERRORID__MODE_LIMIT_REACHED, ERRORID__SPAWN_UNRECOGNIZED,
	ERRORID__UNSAFE_RANGE, ERRORID__CANT_SET_ELEMENT, ERRORID__CANT_REMOVE_ELEMENT, ERRORID__CANT_DELETE_CFG,
	ERRORID__SOME_SPAWN_UNINITIALIZED, ERRORID__UNDEF_MODE_DETECTED }

enum _:TEAM_ENUM { TEAMID_TT, TEAMID_CT }

enum { MTE__ALL, MTE__ONLY_Y, MTE__NO_ANGLES, MTE__BRUSH_ORIGIN }

enum { CA__MINUS, CA__PLUS }

enum { HIGHLIGHT__ONLY_BEAM, HIGHLIGHT__FULL, HIGHLIGHT__NO_SIDE_LINES }

enum _:VECTOR_ENUM { VECTOR_X, VECTOR_Y, VECTOR_Z }
new const VEC_CHAR[VECTOR_ENUM] = { 'X', 'Y', 'Z' }

enum { HUD_MODE__OFF, HUD_MODE__HUD, HUD_MODE__DHUD }

enum _:ELEMENT_ENUM { ELEMENT_SPAWN, ELEMENT_BLOCK, ELEMENT_MODEL, ELEMENT_BUYZONE, ELEMENT_BOMBSPOT, ELEMENT_MODE }
new Array:g_aArray[ELEMENT_ENUM - 1]

new const MIN_MODE_VALUE[ELEMENT_ENUM - 1] = { 1, 0, 0, 0, -1 }

enum _:CVAR_ENUM {
	CVAR__HUD_MODE,
	CVAR__HUD_DURATION,
	CVAR__HUD_R,
	CVAR__HUD_G,
	CVAR__HUD_B,
	CVAR__HUD_X,
	CVAR__HUD_Y,
	CVAR__HL_MODELS
}

enum _:MODE_DATA_STRUCT { PLAYER_COUNT, Float:ROUND_TIME, ROUND_TIME_STR[ROUND_TIME_LEN],
	CHAT_DESC[BIG_BUFF_LEN], CHAT_COLOR, POSTFIX[POSTFIX_LEN] }

new g_eModeData[MODE_DATA_STRUCT], g_eCvar[CVAR_ENUM], g_pUser, g_iMenuType, g_iMenuChar, g_iInputMode
new g_iBeamSprID, g_iBoxSprID, g_iHighlightMode, Float:g_fOffset = NORMAL_OFFSET, Float:g_fSizeStep = 10.0
new bool:g_bBlockModels = true, bool:g_bBlockSolid = true, g_iAxis, g_iAngle, bool:g_bLinked, bool:g_bHasBind
new Array:g_aCache, Trie:g_tBinds, g_iCache, g_iSpawns, g_iLinks, g_iBlocks, g_iModels, g_iBuyZones
new g_iBombSpots, g_iSpawn, g_iBlock, g_iModel, g_iBuyZone, g_iBombSpot, g_iBlockPos, g_iModelPos, g_iCachePos
new g_iBuyZonePos, g_iBombSpotPos, g_szMenu[MENU_LEN],g_szMapName[MAPNAME_LEN],	g_szString[BIG_STRING_LEN]
new g_szCfgDir[PLATFORM_MAX_PATH], g_szErrorLog[PLATFORM_MAX_PATH], Array:g_aModeData, bool:g_bHaveSpawns
new g_iModes, g_iModePos, g_iElemCount[ELEMENT_ENUM - 1], g_szCfgFile[PLATFORM_MAX_PATH], g_iStrPos
new bool:g_bHaveError, g_szBigBuff[BIG_BUFF_LEN], g_szSmBuff[SM_BUFF_LEN], g_msgSendAudio, g_hHudSyncObj
new bool:g_bRangeCheck = true

/****************************************************************************************
************************************* INITIALIZATION ************************************
****************************************************************************************/

public plugin_precache() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

	if(!get_cvar_pointer("MapBalance")) {
		set_fail_state("Run main plugin to register cvars, then run this plugin!")
	}

	bind_pcvar_num(get_cvar_pointer("mb_hl_models"), g_eCvar[CVAR__HL_MODELS])

	register_dictionary("MapBalanceWizard.txt")
	register_dictionary("MapBalance.txt")

	for(new i; i < sizeof(SPAWN_MODEL); i++) {
		precache_model(SPAWN_MODEL[i])
	}

	g_iBeamSprID = precache_model(UNSAFE_BEAM_SPRITE)
	g_iBoxSprID = precache_model(BOX_LINE_SPRITE)
	precache_model(BLOCK_MODEL)

	precache_sound(SOUND__BLIP1)
	precache_sound(SOUND__ERROR)

	get_localinfo("amxx_logs", g_szErrorLog, chx(g_szErrorLog))
	format(g_szErrorLog, chx(g_szErrorLog), "%s/%s", g_szErrorLog, ERROR_LOG_NAME)

	get_localinfo("amxx_configsdir", g_szCfgDir, chx(g_szCfgDir))
	format(g_szCfgDir, chx(g_szCfgDir), "%s/%s", g_szCfgDir, CFG_FOLDER_NAME)

	get_mapname(g_szMapName, chx(g_szMapName))
	formatex(g_szCfgFile, chx(g_szCfgFile), "%s/%s-models.ini", g_szCfgDir, g_szMapName)

	new hFile = fopen(g_szCfgFile, FOPEN_READ)

	if(!hFile) {
		if(file_exists(g_szCfgFile)) {
			func_InitError()
			log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", g_szCfgFile)
		}

		formatex(g_szCfgFile, chx(g_szCfgFile), "%s/default_models.ini", g_szCfgDir, g_szMapName)

		hFile = fopen(g_szCfgFile, FOPEN_READ)

		if(!hFile) {
			if(file_exists(g_szCfgFile)) {
				func_InitError()
				log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", g_szCfgFile)
			}

			return
		}
	}

	g_aCache = ArrayCreate(BIG_BUFF_LEN)

	new szNum[3], iNum

	while(!feof(hFile)) {
		g_iStrPos++; fgets(hFile, g_szString, chx(g_szString))

		switch(g_szString[0]) {
			case ';', '/', '^n': {
				continue
			}
		}

		if(!isdigit(g_szString[0])) {
			func_InitError()
			log_to_file(g_szErrorLog, "[MDLCFG] %L", LANG_SERVER, "MB__CANT_RECOGNIZE_STRING", g_iStrPos)
			continue
		}

		parse(g_szString, szNum, chx(szNum), g_szBigBuff, chx(g_szBigBuff))

		iNum = str_to_num(szNum)

		if(iNum - g_iCache != 1) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
				LANG_SERVER, "MB__WRONG_MDL_ENUM", iNum, g_iCache );

			continue
		}

		if(!g_eCvar[CVAR__HL_MODELS] && !file_exists(g_szBigBuff)) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
				LANG_SERVER, "MB__MDL_NOT_FOUND", g_szBigBuff );

			continue
		}

		precache_model(g_szBigBuff)

		ArrayPushString(g_aCache, g_szBigBuff)
		g_iCache++
	}

	fclose(hFile)
}

/* -------------------- */

public plugin_cfg() {
	g_msgSendAudio = get_user_msgid("SendAudio")

	bind_pcvar_num(get_cvar_pointer("mb_hud_mode"), g_eCvar[CVAR__HUD_MODE])
	bind_pcvar_float(get_cvar_pointer("mb_hud_duration"), Float:g_eCvar[CVAR__HUD_DURATION])
	bind_pcvar_num(get_cvar_pointer("mb_hud_r_custom"), g_eCvar[CVAR__HUD_R])
	bind_pcvar_num(get_cvar_pointer("mb_hud_g_custom"), g_eCvar[CVAR__HUD_G])
	bind_pcvar_num(get_cvar_pointer("mb_hud_b_custom"), g_eCvar[CVAR__HUD_B])
	bind_pcvar_float(get_cvar_pointer("mb_hud_x"), Float:g_eCvar[CVAR__HUD_X])
	bind_pcvar_float(get_cvar_pointer("mb_hud_y"), Float:g_eCvar[CVAR__HUD_Y])

	register_clcmd(MENU_CONCMD, "clcmd_OpenMainMenu", ACCESS_FLAG)

	g_hHudSyncObj = CreateHudSyncObj()

	/* --- */

	formatex(g_szCfgFile, chx(g_szCfgFile), "%s/%s%s.ini", g_szCfgDir, CFG_PREFIX, g_szMapName)

	new hFile = fopen(g_szCfgFile, FOPEN_READ)

	if(!hFile) {
		if(file_exists(g_szCfgFile)) {
			func_InitError()
			log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__CANT_READ_FILE", g_szCfgFile)
		}

		return
	}

	func_Initialize(INITIALIZE__FULL)

	#define TOTAL_ARGC_SPAWN 9
	#define TOTAL_ARGC_BLOCK 12
	#define TOTAL_ARGC_MODEL 19
	#define TOTAL_ARGC_BUYZONE 12
	#define TOTAL_ARGC_BOMBSPOT 5
	#define TOTAL_ARGC_MODE 6

	const BUFFER_CELLS = TOTAL_ARGC_MODEL

	new const iArgCount[ELEMENT_ENUM] = { TOTAL_ARGC_SPAWN, TOTAL_ARGC_BLOCK, TOTAL_ARGC_MODEL,
		TOTAL_ARGC_BUYZONE,	TOTAL_ARGC_BOMBSPOT, TOTAL_ARGC_MODE }

	new szBuffer[BUFFER_CELLS][SM_BUFF_LEN], iModeID, iPos, iArg, i, a, iEnt, iLastPlayerNum;

	new Float:fDefOrigin[XYZ], Float:fModOrigin[XYZ], Float:fCompOrigin[XYZ], Float:fOrigin[XYZ],
		Float:fAngles[XYZ], Float:fMins[XYZ], Float:fMaxs[XYZ], Float:fColor[XYZ];

	g_iStrPos = 0

	while(!feof(hFile))	{
		g_iStrPos++; fgets(hFile, g_szString, chx(g_szString))
		trim(g_szString)

		switch(g_szString[0]) {
			case 'T', 'C': {
				iModeID = ELEMENT_SPAWN
			}
			case 'M': {
				iModeID = g_szString[1] == 'O' ? ELEMENT_MODE : ELEMENT_MODEL
			}
			case 'B': {
				switch(g_szString[1]) {
					case 'L': {
						iModeID = ELEMENT_BLOCK
					}
					case 'U': {
						iModeID = ELEMENT_BUYZONE
					}
					default: { // case 'O'
						iModeID = ELEMENT_BOMBSPOT
					}
				}
			}
			case ';', '/', EOS: {
				continue
			}
			default: {
				func_InitError()
				log_to_file(g_szErrorLog, "[MAPCFG] %L", LANG_SERVER, "MB__CANT_RECOGNIZE_STRING", g_iStrPos)
				continue
			}
		}

		iPos = a = 0
		iArg = strlen(g_szString)

		while(iPos != iArg) {
			if(a == BUFFER_CELLS) {
				func_InitError()

				log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
					LANG_SERVER, "MB__ARG_LIMIT_EXCEEEDED", BUFFER_CELLS );

				iModeID = INVALID_HANDLE
				break
			}

			iPos = argparse(g_szString, iPos, szBuffer[a++], chx(szBuffer[]))
		}

		if(iModeID == INVALID_HANDLE) {
			continue
		}

		if(a != iArgCount[iModeID]) {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
				LANG_SERVER, "MB__WRONG_ARG_COUNT", a, iArgCount[iModeID] );

			continue
		}

		switch(iModeID) {
			case ELEMENT_SPAWN: {
				for(i = 0, a = 1; i < XYZ; i++) {
					fDefOrigin[i] = str_to_float(szBuffer[a++]) // default origin
				}

				for(i = 0; i < XYZ; i++) {
					fModOrigin[i] = str_to_float(szBuffer[a++]) // modified origin
				}

				fAngles[X] = fAngles[Z] = 0.0
				fAngles[Y] = str_to_float(szBuffer[a++]) // modified angle Y

				for(i = 0; i < g_iSpawns; i++) {
					iEnt = ArrayGetCell(Array:g_aArray[ELEMENT_SPAWN], i)

					entity_get_vector(iEnt, EV_VEC_origin, fCompOrigin)

					if(xs_vec_equal(fDefOrigin, fCompOrigin)) {
						break
					}
				}

				if(i == g_iSpawns) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__SPAWN_NOT_FOUND", g_szString[0] == 'T' ? "TT" : "CT",
						fDefOrigin[X], fDefOrigin[Y], fDefOrigin[Z]
					);

					continue
				}

				if(!func_CreateAndLinkOffset(iEnt, fModOrigin, fAngles)) {
					func_InitError()
					func_GetElementLang(ELEMENT_SPAWN)

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__CANT_SET_ELEMENT", LANG_SERVER, "MB__CREATE_S",
						LANG_SERVER, g_szBigBuff );

					continue
				}
			}
			case ELEMENT_BLOCK:	{
				for(i = 0, a = 1; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szBuffer[a++])
				}

				fAngles[X] = fAngles[Z] = 0.0
				fAngles[Y] = str_to_float(szBuffer[a++])

				for(i = 0; i < XYZ; i++) {
					fMins[i] = str_to_float(szBuffer[a++])
				}

				for(i = 0; i < XYZ; i++) {
					fMaxs[i] = str_to_float(szBuffer[a++])
				}

				iEnt = func_CreateElement(ELEMENT_BLOCK, INFO_TARGET, g_iBlockPos, g_iBlocks, fOrigin, fAngles)

				if(!iEnt) {
					continue
				}

				entity_set_int(iEnt, EV_INT_solid, SOLID_BBOX)
				entity_set_size(iEnt, fMins, fMaxs)
			}
			case ELEMENT_MODEL: {
				iArg = str_to_num(szBuffer[1])

				if(iArg < 1 || iArg > g_iCache) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__WRONG_MODEL_ID", iArg, g_iCache ? 1 : 0, g_iCache );

					continue
				}

				g_iCachePos = iArg - 1

				for(i = 0, a = 2; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szBuffer[a++])
				}

				for(i = 0; i < XYZ; i++) {
					fAngles[i] = str_to_float(szBuffer[a++])
				}

				iEnt = func_CreateElement(ELEMENT_MODEL, ENV_SPRITE, g_iModelPos, g_iModels, fOrigin, fAngles)

				if(!iEnt) {
					continue
				}

				entity_set_float(iEnt, EV_FL_scale, str_to_float(szBuffer[a++]))
				entity_set_int(iEnt, EV_INT_sequence, str_to_num(szBuffer[a++]))
				entity_set_float(iEnt, EV_FL_frame, str_to_float(szBuffer[a++]))
				entity_set_float(iEnt, EV_FL_framerate, str_to_float(szBuffer[a++]))
				entity_set_int(iEnt, EV_INT_rendermode, str_to_num(szBuffer[a++]))
				entity_set_int(iEnt, EV_INT_renderfx, str_to_num(szBuffer[a++]))
				entity_set_float(iEnt, EV_FL_renderamt, str_to_float(szBuffer[a++]))

				for(i = 0; i < RGB; i++) {
					fColor[i] = str_to_float(szBuffer[a++])
				}

				entity_set_vector(iEnt, EV_VEC_rendercolor, fColor)
			}
			case ELEMENT_BUYZONE: {
				if((iArg = szBuffer[1][0]) != 'T' && iArg != 'C') {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__WRONG_TEAM_ID", szBuffer[1] );

					continue
				}

				for(i = 0, a = 2; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szBuffer[a++])
				}

				for(i = 0; i < XYZ; i++) {
					fMins[i] = str_to_float(szBuffer[a++])
				}

				for(i = 0; i < XYZ; i++) {
					fMaxs[i] = str_to_float(szBuffer[a++])
				}

				iEnt = func_CreateElement(ELEMENT_BUYZONE, FUNC_BUYZONE, g_iBuyZonePos, g_iBuyZones, fOrigin)

				if(!iEnt) {
					continue
				}

				iArg = iArg == 'T' ? 0 : 1;

				entity_set_int(iEnt, ENTVAR__BUYZONE_TEAM_ID, iArg)
				DispatchKeyValue(iEnt, BZ_TEAM_KEY, iArg ? "2" : "1")
				entity_set_size(iEnt, fMins, fMaxs)
			}
			case ELEMENT_BOMBSPOT: {
				for(i = 0, a = 1; i < XYZ; i++) {
					fOrigin[i] = str_to_float(szBuffer[a++])
				}

				for(i = 0; i < g_iBombSpots; i++) {
					iEnt = ArrayGetCell(Array:g_aArray[ELEMENT_BOMBSPOT], i)

					entity_get_vector(iEnt, EV_VEC_origin, fCompOrigin)

					if(origin_is_null(fCompOrigin)) {
						entity_get_vector(iEnt, EV_VEC_mins, fMins)
						entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)
						func_GetBrushEntOrigin(fMins, fMaxs, fCompOrigin)
					}

					if(xs_vec_equal(fOrigin, fCompOrigin)) {
						break
					}
				}

				if(i == g_iBombSpots) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__BOMBSPOT_NOT_FOUND", fOrigin[X], fOrigin[Y], fOrigin[Z] );

					continue
				}
			}
			case ELEMENT_MODE: {
				if(g_iModes == MAX_MODES) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__MODE_LIMIT_REACHED" );

					continue
				}

				if((iArg = str_to_num(szBuffer[2])) < 1 || iArg < iLastPlayerNum) {
					func_InitError()

					log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
						LANG_SERVER, "MB__WRONG_PLAYERS_NUM", iArg, iLastPlayerNum );

					continue
				}

				g_eModeData[PLAYER_COUNT] = iLastPlayerNum = iArg

				parse(g_szString, "", "", g_eModeData[CHAT_DESC], chx(g_eModeData[CHAT_DESC]))

				g_eModeData[ROUND_TIME] = str_to_float(szBuffer[3])
				func_SetRoundTimeStr()

				switch(szBuffer[4][0]) {
					case 'd': iArg = print_team_default
					case 'w': iArg = print_team_grey
					case 'r': iArg = print_team_red
					case 'b': iArg = print_team_blue
					default: {
						iArg = print_team_default

						func_InitError()

						log_to_file(g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
							LANG_SERVER, "MB__WRONG_COLOR_ID", szBuffer[4])
					}
				}

				g_eModeData[CHAT_COLOR] = iArg

				if(szBuffer[5][0]) {
					copy(g_eModeData[POSTFIX], chx(g_eModeData[POSTFIX]), szBuffer[5])
				}
				else {
					g_eModeData[POSTFIX][0] = EOS
				}

				ArrayPushArray(g_aModeData, g_eModeData)

				g_iModes++

				continue // !!!
			}
		}

		func_LinkElement(iEnt, szBuffer[a], iModeID)
	}

	fclose(hFile)
	func_ToggleSpawnsVisibility(SET_INVISIBLE)
}

/* -------------------- */

stock func_Initialize(bool:bMode) {
	g_aModeData = ArrayCreate(MODE_DATA_STRUCT)

	for(new i; i < sizeof(g_aArray); i++) {
		g_aArray[i] = ArrayCreate(1)
	}

	g_tBinds = TrieCreate()

	new iEnt = MaxClients

	while((iEnt = find_ent_by_class(iEnt, FUNC_BOMB_TARGET))) {
		if(!g_iBombSpot) {
			g_iBombSpot = iEnt
		}

		ArrayPushCell(Array:g_aArray[ELEMENT_BOMBSPOT], iEnt)
		g_iBombSpots++
	}

	register_touch("weaponbox", MBW_BLOCK_CLASSNAME, "engfwd_Touch")

	if(bMode/* == INITIALIZE__FULL*/) {
		func_MakeSpawns()
	}
}

/****************************************************************************************
*************************************** MAIN MENU ***************************************
****************************************************************************************/

public clcmd_OpenMainMenu(id, iAccess) {
	ACCESS_FLAG = iAccess

	if(player_has_access(id) && (!g_pUser || id == g_pUser)) {
		static bool:bInit

		if(!bInit) {
			bInit = true

			register_impulse(201, "func_ClCmdNoClip")
			register_clcmd("mbw_input", "clcmd_InputHandler")

			register_menucmd(register_menuid(MENU_IDENT_STRING__MBW), ALL_KEYS, "func_Menu_Handler")

			if(g_bHaveError) {
				func_ErrorHandler(ERRORID__SOMETHING_WRONG)
			}

			if(!g_aModeData) {
				func_Initialize(INITIALIZE__WITHOUT_SPAWNS)
			}
		}

		if(is_user_alive((g_pUser = id))) {
			entity_set_float(id, EV_FL_takedamage, DAMAGE_NO)
		}

		g_iInputMode = 0
		func_MainMenu(id)
	}

	return PLUGIN_HANDLED
}

/* -------------------- */

stock func_MainMenu(id) {
	func_OverCurrMode()

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L %s^n^n\
		1. \w%L^n\
		\y2. \w%L^n\
		\y3. \w%L^n\
		\y4. \%c%L^n\
		\y5. \w%L^n\
		\y6. \%c%L^n^n\
		\y7. \w%L^n\
		\y8. \%c%L^n^n\
		\y9. \w%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__MAIN_MENU", PLUGIN_NAME,
		id, "MB__WORK_WITH_MODES",
		id, "MB__WORK_WITH_SPAWNS",
		id, "MB__WORK_WITH_BLOCKS",
		g_iCache ? _W_ : _D_, id, "MB__WORK_WITH_MODELS",
		id, "MB__WORK_WITH_BUYZONES",
		g_iBombSpots ? _W_ : _D_, id, "MB__WORK_WITH_BOMBSPOTS",
		id, "MB__CORDS_IN_CONSOLE",
		file_exists(g_szCfgFile) ? _W_ : _D_, id, "MB__DELETE_CFG",
		id, "MB__CREATE_CFG",
		id, "MB__EXIT"
	);

	return func_ShowMenu(id, ALL_KEYS, MENUTYPE__MAIN_MENU)
}

/* -------------------- */

stock func_MainMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: {
			return func_ModeMenu(id)
		}
		case _KEY2_: {
			g_bHaveSpawns ?
				func_ToggleSpawnsVisibility(SET_VISIBLE)
				:
				func_MakeSpawns();

			return func_SpawnMenu(id)
		}
		case _KEY3_: {
			func_SetHighlightTask(HIGHLIGHT__FULL)
			func_SetCurrBlockSolidType(SOLID_NOT)

			return func_BlockMenu(id)
		}
		case _KEY4_: {
			if(g_iCache) {
				func_SetHighlightTask(HIGHLIGHT__ONLY_BEAM)
				return func_ModelMenu(id)
			}
			//else ->
			func_ErrorHandler(ERRORID__PRECACHE_IS_EMPTY)
		}
		case _KEY5_: {
			func_SetHighlightTask(HIGHLIGHT__FULL)
			return func_BuyZoneMenu(id)
		}
		case _KEY6_: {
			if(g_iBombSpots) {
				func_SetHighlightTask(HIGHLIGHT__NO_SIDE_LINES)
				return func_BombSpotMenu(id)
			}
			//else ->
			func_ErrorHandler(ERRORID__NO_BOMBSPOTS)
		}
		case _KEY7_: {
			func_SendAudio(id, SOUND__BLIP1)
			client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__INFO_PRINTED_IN_CONSOLE")

			new Float:fOrigin[XYZ], Float:fAngles[XYZ]

			entity_get_vector(id, EV_VEC_origin, fOrigin)
			entity_get_vector(id, EV_VEC_angles, fAngles)

			console_print( id, "^n%s %L", PLUGIN_PREFIX, id, "MB__YOUR_ORIGIN",
				fOrigin[X], fOrigin[Y], fOrigin[Z] );

			console_print( id, "%s %L", PLUGIN_PREFIX, id, "MB__YOUR_ANGLES",
				fAngles[X], fAngles[Y], fAngles[Z] );

			if((entity_get_int(id, EV_INT_button) & IN_DUCK) || (~entity_get_int(id, EV_INT_flags) & FL_ONGROUND)) {
				console_print(id, "%s %L^n", PLUGIN_PREFIX, id, "MB__YOUR_FLOOR_NA")
			}
			else {
				console_print(id, "%s %L^n", PLUGIN_PREFIX, id, "MB__YOUR_FLOOR_IS", fOrigin[Z] - PLAYER_CENTER_HEIGHT)
			}
		}
		case _KEY8_: {
			if(file_exists(g_szCfgFile)) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY9_: {
			if(!dir_exists(g_szCfgDir)) {
				mkdir(g_szCfgDir)
			}

			new hFile = fopen(g_szCfgFile, FOPEN_WRITE)

			if(!hFile) {
				func_ErrorHandler(ERRORID__CANT_WRITE_TO_CFG)
			}
			else {
				fprintf(hFile, "// %L^n^n", LANG_SERVER, "MB__CFG_READY_1")

				for(new i; i < g_iModes; i++) {
					func_GetModeData(i)

					switch(g_eModeData[CHAT_COLOR]) {
						case print_team_default: g_szSmBuff = "default"
						case print_team_grey: g_szSmBuff = "white"
						case print_team_red: g_szSmBuff = "red"
						case print_team_blue: g_szSmBuff = "blue"
					}

					fprintf( hFile, "MODE: ^"%s^" %d %.2f %s ^"%s^"^n", g_eModeData[CHAT_DESC], g_eModeData[PLAYER_COUNT],
						g_eModeData[ROUND_TIME], g_szSmBuff, g_eModeData[POSTFIX] );
				}

				/* --- */

				new bool:bError, iErrNum[ELEMENT_ENUM - 2], Float:fOrigin[XYZ], Float:fModOrigin[XYZ],
					Float:fAngles[XYZ],	Float:fMins[XYZ], Float:fMaxs[XYZ], Float:fColor[XYZ]

				func_GetElementCount()

				for(new a, i, iEnt, iOffsetEnt, iLinks = g_iLinks; a < ELEMENT_MODE; a++) {
					if(!g_iElemCount[a]) {
						continue
					}

					for(i = 0; i < g_iElemCount[a]; i++) {
						iEnt = ArrayGetCell(g_aArray[a], i)

						if(!func_GetBindedModes_Step2(iEnt)) {
							if(a == ELEMENT_SPAWN) {
								if(!entity_get_int(iEnt, ENTVAR__LINKED_SPAWN_ID))
									continue
							}

							if(a == ELEMENT_BOMBSPOT) {
								continue
							}

							bError = true
							iErrNum[a]++
							g_szBigBuff[0] = EOS
							fputs(hFile, "//")
						}

						entity_get_vector(iEnt, EV_VEC_origin, fOrigin)

						switch(a) {
							case ELEMENT_SPAWN: {
								iOffsetEnt = entity_get_int(iEnt, ENTVAR__LINKED_SPAWN_ID)

								entity_get_vector(iOffsetEnt, EV_VEC_origin, fModOrigin)
								entity_get_vector(iOffsetEnt, EV_VEC_angles, fAngles)

								fprintf( hFile, "%cT: %f %f %f %.0f %.0f %.0f %.0f ^"%s^"^n",
									entity_get_int(iEnt, ENTVAR__MDL_ID_TO_LINK) == TEAM_ENUM ? 'T' : 'C',
									fOrigin[X], fOrigin[Y], fOrigin[Z], fModOrigin[X], fModOrigin[Y],
									fModOrigin[Z], fAngles[Y], g_szBigBuff );

								if(--iLinks == 0) {
									break
								}
							}
							case ELEMENT_BLOCK:	{
								entity_get_vector(iEnt, EV_VEC_angles, fAngles)
								entity_get_vector(iEnt, EV_VEC_mins, fMins)
								entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)

								fprintf( hFile,
									"BLOCK: %.1f %.1f %.1f %.0f %.1f %.1f %.1f %.1f %.1f %.1f ^"%s^"^n",
									fOrigin[X], fOrigin[Y], fOrigin[Z], fAngles[Y], fMins[X],
									fMins[Y], fMins[Z], fMaxs[X], fMaxs[Y], fMaxs[Z], g_szBigBuff );
							}
							case ELEMENT_MODEL:	{
								entity_get_vector(iEnt, EV_VEC_angles, fAngles)
								entity_get_vector(iEnt, EV_VEC_rendercolor, fColor)

								fprintf( hFile,
									"MDL: %d %.1f %.1f %.1f \
									%.0f %.0f %.0f %.2f %d %.0f %.2f %d %d %.0f %.0f %.0f %.0f ^"%s^"^n",

									entity_get_int(iEnt, ENTVAR__MDL_ID_TO_LINK),
									fOrigin[X], fOrigin[Y], fOrigin[Z], fAngles[X], fAngles[Y],
									fAngles[Z], entity_get_float(iEnt, EV_FL_scale),
									entity_get_int(iEnt, EV_INT_sequence), entity_get_float(iEnt, EV_FL_frame),
									entity_get_float(iEnt, EV_FL_framerate), entity_get_int(iEnt, EV_INT_rendermode),
									entity_get_int(iEnt, EV_INT_renderfx), entity_get_float(iEnt, EV_FL_renderamt),
									fColor[X], fColor[Y], fColor[Z], g_szBigBuff
								);
							}
							case ELEMENT_BUYZONE: {
								entity_get_vector(iEnt, EV_VEC_mins, fMins)
								entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)

								fprintf( hFile, "BUYZONE: %cT %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f ^"%s^"^n",
									entity_get_int(iEnt, ENTVAR__BUYZONE_TEAM_ID) ? 'C' : 'T',
									fOrigin[X], fOrigin[Y], fOrigin[Z], fMins[X], fMins[Y],
									fMins[Z], fMaxs[X], fMaxs[Y], fMaxs[Z], g_szBigBuff );
							}
							case ELEMENT_BOMBSPOT: {
								if(origin_is_null(fOrigin)) {
									entity_get_vector(iEnt, EV_VEC_mins, fMins)
									entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)
									func_GetBrushEntOrigin(fMins, fMaxs, fOrigin)
								}

								fprintf( hFile, "BOMBSPOT: %f %f %f ^"%s^"^n", fOrigin[X], fOrigin[Y],
									fOrigin[Z], g_szBigBuff );
							}
						}
					}
				}

				if(bError) {
					func_ErrorHandler(ERRORID__UNBINDED_ELEMENT_DETECTED)

					console_print(id, "^n%s %L", PLUGIN_PREFIX, id, "MB__UNLINKED_ELEMENTS")

					for(new i; i < sizeof(iErrNum); i++) {
						if(iErrNum[i]) {
							func_GetElementLang(i)
							console_print(id, "%L: %d", id, g_szBigBuff, iErrNum[i])
						}
					}

					console_print(id, " ")
				}
				else {
					func_SendAudio(id, SOUND__BLIP1)
				}

				client_print_color( id, print_team_blue, "^4* ^1%L^3 %s%s.ini",
					id, "MB__CFG_SAVED", CFG_PREFIX, g_szMapName );
			}

			fclose(hFile)
		}
		case _KEY0_: {
			if(is_user_alive(id)) {
				entity_set_float(id, EV_FL_takedamage, DAMAGE_AIM)
				entity_set_int(id, EV_INT_movetype, MOVETYPE_WALK)
			}

			return g_pUser = 0
		}
	}

	return func_MainMenu(id)
}

/****************************************************************************************
************************************** MODES MENU ***************************************
****************************************************************************************/

stock func_ModeMenu(id) {
	g_iMenuChar = g_iModes ? _W_ : _D_;

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n^n\
		1. \%c%L \y(%d|%d)^n\
		2. \%c%L^n\
		\y3. \%c%L^n\
		\y4. \%c%L^n\
		\y5. \%c%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX,
		id, "MB__WORK_WITH_MODES",
		g_iMenuChar, id, "MB__EDIT_MODE", g_iModes ? g_iModePos + 1 : 0, g_iModes, // Edit current
		g_iModePos ? _W_ : _D_, id, "MB__PREV_MODE", // Previous
		(g_iModePos < g_iModes - 1) ? _W_ : _D_, id, "MB__NEXT_MODE", // Next
		g_iModes == MAX_MODES ? _D_ : _W_, id, "MB__CREATE_MODE", // Create new
		g_iMenuChar, id, "MB__DELETE_MODE", // Delete current
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_0, MENUTYPE__MODE_MENU)
}

/* -------------------- */

stock func_ModeMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: { // Edit current
			if(g_iModes) {
				return func_ModeSubMenu(id)
			}
		}
		case _KEY2_: { // Previous
			if(g_iModePos) {
				func_GetModeData(--g_iModePos)
			}
		}
		case _KEY3_: { // Next
			if(g_iModePos < g_iModes - 1) {
				func_GetModeData(++g_iModePos)
			}
		}
		case _KEY4_: { // Create new
			if(g_iModes == MAX_MODES) {
				func_ErrorHandler(ERRORID__MODE_LIMIT_REACHED)
			}
			else {
				if(g_iModes) {
					func_GetModeData(g_iModes - 1)
				}

				g_eModeData[PLAYER_COUNT] = max(1, g_eModeData[PLAYER_COUNT])
				g_eModeData[ROUND_TIME] = 0.0
				func_SetRoundTimeStr()
				formatex(g_eModeData[CHAT_DESC], chx(g_eModeData[CHAT_DESC]), "%L", g_pUser, "MB__NEW_MODE")
				g_eModeData[CHAT_COLOR] = print_team_default
				g_eModeData[POSTFIX] = ""

				ArrayPushArray(g_aModeData, g_eModeData)

				g_iModePos = g_iModes++

				func_ElementInfo(ELEMENT_MODE)

				return func_ModeSubMenu(id)
			}
		}
		case _KEY5_: // Delete current
		{
			if(g_iModes) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_ModeMenu(id)
}

/* -------------------- */

stock func_ModeSubMenu(id) {
	func_GetModeData(g_iModePos)

	if(!g_eModeData[CHAT_DESC][0]) {
		g_eModeData[CHAT_DESC] = NO_VALUE
	}

	new iChatColor = g_eModeData[CHAT_COLOR]

	if(iChatColor < 0) {
		iChatColor = -iChatColor
	}

	formatex(g_szSmBuff, chx(g_szSmBuff), "MB__COLOR_%d", iChatColor + 1)

	if(!g_eModeData[ROUND_TIME]) {
		g_eModeData[ROUND_TIME_STR] = NO_VALUE
	}

	if(!g_eModeData[POSTFIX][0]) {
		g_eModeData[POSTFIX] = NO_VALUE
	}

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L (%d|%d)^n^n\
		1. \w%L: \y%d^n\
		2. \w%L: \y%s^n\
		\y3. \w%L '!t': \y%L^n\
		4. \w%L: \y%s^n\
		\y5. \w%L: \y%s^n\
		\y6. \w%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__MODE_EDITING",	g_iModePos + 1, g_iModes,
		id, "MB__PLAYER_COUNT", g_eModeData[PLAYER_COUNT], // Player count
		id, "MB__MODE_NAME", g_eModeData[CHAT_DESC], // Description
		id, "MB__COLOR_FOR", id, g_szSmBuff, // Color
		id, "MB__ROUND_TIME", g_eModeData[ROUND_TIME_STR], // Roundtime
		id, "MB__POSTFIX", g_eModeData[POSTFIX], // Postfix
		id, "MB__TEST_OUTPUT",
		id, "MB__BACK"
	);

	func_GetModeData(g_iModePos)

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_0, MENUTYPE__MODE_SUBMENU)
}

/* -------------------- */

stock func_SetRoundTimeStr() {
	if(g_eModeData[ROUND_TIME])	{
		new iSec, iMin = (iSec = floatround(floatmul(g_eModeData[ROUND_TIME], 60.0))) / SECONDS_IN_MINUTE

		iSec = max(0, (iSec -= (iMin * SECONDS_IN_MINUTE)))

		formatex( g_eModeData[ROUND_TIME_STR], chx(g_eModeData[ROUND_TIME_STR]), "%d:%s%d",
			iMin, (iSec < 10) ? "0" : "", iSec );

		return
	}

	g_eModeData[ROUND_TIME_STR] = "0:00"
}

/* -------------------- */

stock func_ModeSubMenu_SubHandler(id, iKey) {
	if(iKey == _KEY6_) {
		copy(g_szBigBuff, chx(g_szBigBuff), g_eModeData[CHAT_DESC])

		replace_string(g_szBigBuff, chx(g_szBigBuff), "!n", "^1")
		replace_string(g_szBigBuff, chx(g_szBigBuff), "!t", "^3")
		replace_string(g_szBigBuff, chx(g_szBigBuff), "!g", "^4")

		client_print_color( id, g_eModeData[CHAT_COLOR], "^4%s ^1%L", PLUGIN_PREFIX, id, "MB__MODE_ANNOUNCE",
			g_eModeData[PLAYER_COUNT], g_szBigBuff, g_eModeData[ROUND_TIME_STR] );

		if(g_eCvar[CVAR__HUD_MODE] != HUD_MODE__OFF) {

			replace_string(g_szBigBuff, chx(g_szBigBuff), "^1", "")
			replace_string(g_szBigBuff, chx(g_szBigBuff), "^3", "")
			replace_string(g_szBigBuff, chx(g_szBigBuff), "^4", "")

			if(g_eCvar[CVAR__HUD_MODE] == HUD_MODE__HUD) {
				set_hudmessage( g_eCvar[CVAR__HUD_R], g_eCvar[CVAR__HUD_G], g_eCvar[CVAR__HUD_B], Float:g_eCvar[CVAR__HUD_X], Float:g_eCvar[CVAR__HUD_Y],
					0, 0.0, Float:g_eCvar[CVAR__HUD_DURATION], 0.1, 0.1, -1 );

				ShowSyncHudMsg(0, g_hHudSyncObj, "%L %s", LANG_PLAYER, "MB__GAME_MODE", g_szBigBuff)
			}
			else { // HUD_MODE__DHUD
				set_dhudmessage( g_eCvar[CVAR__HUD_R], g_eCvar[CVAR__HUD_G], g_eCvar[CVAR__HUD_B], Float:g_eCvar[CVAR__HUD_X], Float:g_eCvar[CVAR__HUD_Y],
					0, 0.0, Float:g_eCvar[CVAR__HUD_DURATION], 0.1, 0.1 );

				show_dhudmessage(id, "%L %s", id, "MB__GAME_MODE", g_szBigBuff)
			}
		}

		return func_ModeSubMenu(id)
	}
	if(iKey == _KEY0_) {
		return func_ModeMenu(id)
	}

	return func_PromtArgument(id, PROMTMODE__SET_MODE_PLAYERS + iKey)
}

/****************************************************************************************
************************************** SPAWNS MENU **************************************
****************************************************************************************/

stock func_SpawnMenu(id) {
	g_bLinked = (g_iSpawn && entity_get_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID))

	func_GetBindedModes_Step1(g_bLinked, g_iSpawn)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n\
		%L \w%s^n^n\
		\y1. \w%L^n\
		\y2. \%c%L %L^n\
		\y3. \w%L: %L^n\
		\y4. \w%L: %L^n\
		\y5. \%c%L^n\
		\y6. \%c%L^n\
		\y7. \%c%L^n^n\
		\y0. \w%L",
		MENU_TITLE_PREFIX,
		id, "MB__WORK_WITH_SPAWNS",
		id, "MB__LINK", g_szBigBuff,
		id, "MB__CHOOSE_SPAWN",
		g_iMenuChar, id, g_bLinked ? "MB__CHANGE" : "MB__CREATE", id, "MB__ELEMENT_1",
		id, "MB__UP_OFFSET", id, (g_fOffset == NORMAL_OFFSET) ? "MB__OFF" : "MB__ON",
		id, "MB__SAFE_RANGE_CHECK", id, g_bRangeCheck ? "MB__ON" : "MB__OFF",
		g_bLinked ? _W_ : _D_, id, "MB__LINK_TO_MODES",
		g_iMenuChar, id, "MB__CORDS_IN_CONSOLE",
		g_bLinked ? _W_ : _D_, id, "MB__REMOVE_OFFSET",
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_0, MENUTYPE__SPAWN_MENU)
}

/* -------------------- */

stock func_SpawnMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: { // Choose spawn
			if(g_iSpawn) {
				func_RemoveGlowShell(g_iSpawn)

				if((g_iSpawn = entity_get_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID)))
					func_RemoveGlowShell(g_iSpawn)
			}

			new bool:bFound, iEnt = func_GetSpawnByAim()

			if(iEnt) {
				entity_get_string(iEnt, EV_SZ_classname, g_szSmBuff, chx(g_szSmBuff))

				if(equal(g_szSmBuff, MBW_SPAWN_CLASSNAME)) {
					bFound = true
					func_SendAudio(id, SOUND__BLIP1)

					new iLinkedEnt

					if((iLinkedEnt = entity_get_int(iEnt, ENTVAR__LINKED_SPAWN_ID))) {
						if(entity_get_int(iEnt, ENTVAR__IS_DEFAULT_SPAWN)) {
							func_SetGlowShell(g_iSpawn = iEnt, COLOR_YELLOW)
							func_SetGlowShell(iLinkedEnt, COLOR_RED)
						}
						else {
							func_SetGlowShell(iEnt, COLOR_RED)
							func_SetGlowShell(g_iSpawn = iLinkedEnt, COLOR_YELLOW)
						}
					}
					else {
						func_SetGlowShell(g_iSpawn = iEnt, COLOR_GREEN)
					}
				}
			}

			if(!bFound) {
				g_iSpawn = 0
				func_ErrorHandler(ERRORID__SPAWN_UNRECOGNIZED)
			}
		}
		case _KEY2_: { // Create/change offset
			if(g_iSpawn) {
				new Float:fOrigin[XYZ], Float:fAngles[XYZ]

				func_GetNormalizedVec(fOrigin, fAngles)
				fOrigin[Z] += g_fOffset

				new iLinkedEnt = entity_get_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID)

				if(func_UnSafeRange(fOrigin, fAngles, iLinkedEnt)) {
					func_ErrorHandler(ERRORID__UNSAFE_RANGE)
				}
				else {
					if(iLinkedEnt) {
						entity_set_origin(iLinkedEnt, fOrigin)
						entity_set_vector(iLinkedEnt, EV_VEC_angles, fAngles)
						func_SendAudio(id, SOUND__BLIP1)
						client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__OFFSET_CHANGED")
					}
					else {
						iLinkedEnt = func_CreateAndLinkOffset(g_iSpawn, fOrigin, fAngles)

						if(iLinkedEnt) {
							func_SetGlowShell(g_iSpawn, COLOR_YELLOW)
							func_SetGlowShell(iLinkedEnt, COLOR_RED)
							func_ElementInfo(ELEMENT_SPAWN)
						}
						else {
							func_GetElementLang(ELEMENT_SPAWN)
							func_ErrorHandler(ERRORID__CANT_SET_ELEMENT)
						}
					}
				}
			}
		}
		case _KEY3_: { // Change up offset
			g_fOffset = (g_fOffset == NORMAL_OFFSET) ? ABOVE_OFFSET : NORMAL_OFFSET
			func_SendAudio(id, SOUND__BLIP1)
		}
		case _KEY4_: { // Toggle range check
			g_bRangeCheck = !g_bRangeCheck
			func_SendAudio(id, SOUND__BLIP1)
		}
		case _KEY5_: { // Bind to modes
			if(g_bLinked) {
				return func_PromtArgument(id, PROMTMODE__MODE_BIND)
			}
		}
		case _KEY6_: { // Coords in console
			if(g_iSpawn) {
				func_SendAudio(id, SOUND__BLIP1)
				client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__INFO_PRINTED_IN_CONSOLE")

				new Float:fOrigin[XYZ], Float:fAngles[XYZ]

				entity_get_vector(g_iSpawn, EV_VEC_origin, fOrigin)
				entity_get_vector(g_iSpawn, EV_VEC_angles, fAngles)

				console_print( id, "^n%s %L", PLUGIN_PREFIX, id, "MB__SPAWN_ORIGIN",
					fOrigin[X], fOrigin[Y], fOrigin[Z] );

				console_print( id, "%s %L", PLUGIN_PREFIX, id, "MB__SPAWN_ANGLES",
					fAngles[X], fAngles[Y], fAngles[Z] );

				new iLinkedEnt = entity_get_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID)

				if(iLinkedEnt) {
					entity_get_vector(iLinkedEnt, EV_VEC_origin, fOrigin)
					entity_get_vector(iLinkedEnt, EV_VEC_angles, fAngles)

					console_print( id, "%s %L", PLUGIN_PREFIX, id, "MB__OFFSET_ORIGIN",
						fOrigin[X], fOrigin[Y], fOrigin[Z] );

					console_print( id, "%s %L", PLUGIN_PREFIX, id, "MB__OFFSET_ANGLES",
						fAngles[X], fAngles[Y], fAngles[Z] );

				}

				console_print(id, " ")
			}
		}
		case _KEY7_: { // Delete
			if(g_bLinked) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_SpawnMenu(id)
}

/****************************************************************************************
************************************** BLOCKS MENU **************************************
****************************************************************************************/

stock func_BlockMenu(id) {
	func_GetBindedModes_Step1(g_iBlock, g_iBlock)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n\
		%L \w%s^n^n\
		\y1. \%c%L \y(%d|%d)^n\
		2. \%c%L^n\
		\y3. \%c%L^n\
		\y4. \%c%L^n\
		\y5. \%c%L^n\
		\y6. \w%L^n\
		\y7. \w%L %L^n\
		\y8. \w%L %L^n\
		\y9. \%c%L^n^n\
		\y0. \w%L",
		MENU_TITLE_PREFIX,
		id, "MB__WORK_WITH_BLOCKS",
		id, "MB__LINK", g_szBigBuff,
		g_iMenuChar, id, "MB__EDIT_BLOCK", g_iBlock ? g_iBlockPos + 1 : 0, g_iBlocks,
		g_iBlockPos ? _W_ : _D_, id, "MB__PREV_BLOCK",
		(g_iBlockPos < g_iBlocks - 1) ? _W_ : _D_, id, "MB__NEXT_BLOCK",
		g_iMenuChar, id, "MB__MOVE_TO_BLOCK",
		g_iMenuChar, id, "MB__LINK_TO_MODES",
		id, "MB__CREATE_NEW_BLOCK",
		id, "MB__MODEL", id, g_bBlockModels ? "MB__ON" : "MB__OFF",
		id, "MB__SOLID", id, g_bBlockSolid ? "MB__ON" : "MB__OFF",
		g_iMenuChar, id, "MB__DELETE_BLOCK",
		id, "MB__BACK"
	);

	return func_ShowMenu(id, ALL_KEYS, MENUTYPE__BLOCK_MENU)
}

/* -------------------- */

stock func_BlockMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: { // Edit current
			if(g_iBlock) {
				return func_BlockSubMenu(id)
			}
		}
		case _KEY2_: { // Previous
			if(g_iBlockPos) {
				func_ChangeBlock(--g_iBlockPos)
			}
		}
		case _KEY3_: { // Next
			if(g_iBlockPos < g_iBlocks - 1) {
				func_ChangeBlock(++g_iBlockPos)
			}
		}
		case _KEY4_: {
			func_MoveToElement(g_iBlock, MTE__ALL)
		}
		case _KEY5_: { // Link to modes
			if(g_iBlock) {
				return func_PromtArgument(id, PROMTMODE__MODE_BIND)
			}
		}
		case _KEY6_: { // Create new
			if(func_CreateElement(ELEMENT_BLOCK, INFO_TARGET, g_iBlockPos, g_iBlocks)) {
				return func_BlockSubMenu(id)
			}
		}
		case _KEY7_: { // Models on/off
			func_ToggleBlockOpt((g_bBlockModels = !g_bBlockModels) ? 1 : 0, TBO__MODELS)
		}
		case _KEY8_: { // Solid on/off
			func_ToggleBlockOpt((g_bBlockSolid = !g_bBlockSolid) ? SOLID_BBOX : SOLID_NOT, TBO__SOLID)
		}
		case _KEY9_: { // Delete current
			if(g_iBlock) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_BlockMenu(id)
}

/* -------------------- */

stock func_BlockSubMenu(id) {
	new Float:fAngles[XYZ]

	entity_get_vector(g_iBlock, EV_VEC_angles, fAngles)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n^n\
		\y1. \w%L \y%c\
		^n      \r2. \w<- %L      \r3. \w-> %L\
		^n      \y4. \w<- %L      \y5. \w-> %L^n^n\
		\w%L \yY (%.0f)\
		^n      \y6. \w<- %L    \y7. \w-> %L^n^n\
		\y8. \w%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__BLOCK_EDITING",
		id, "MB__CHANGE_SIZE_1", VEC_CHAR[g_iAxis],
		id, "MB__TIGHTER", id, "MB__WIDER",
		id, "MB__TIGHTER", id, "MB__WIDER",
		id, "MB__CHANGE_ANGLE", fAngles[Y],
		id, "MB__BACK", id, "MB__FORWARD",
		id, "MB__CHANGE_STEP", g_fSizeStep,
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0, MENUTYPE__BLOCK_SUBMENU)
}

/* -------------------- */

stock func_BlockSubMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: {
			func_ChangeVector(g_iAxis)
		}
		case _KEY2_, _KEY3_, _KEY4_, _KEY5_: {
			if(!func_ChangeSize(g_iBlock, iKey)) {
				return func_BlockSubMenu(id)
			}
		}
		case _KEY6_, _KEY7_: {
			func_ChangeAngle(g_iBlock, iKey == _KEY6_ ? CA__MINUS : CA__PLUS, VECTOR_Y)
		}
		case _KEY8_: {
			func_ChangeSizeStep()
		}
		case _KEY0_: {
			return func_BlockMenu(id)
		}
	}

	func_SendAudio(id, SOUND__BLIP1)
	return func_BlockSubMenu(id)
}

/****************************************************************************************
************************************** MODELS MENU **************************************
****************************************************************************************/

stock func_ModelMenu(id) {
	func_GetBindedModes_Step1(g_iModel, g_iModel)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n\
		%L \w%s^n^n\
		\y1. \%c%L \y(%d|%d)^n\
		2. \%c%L^n\
		\y3. \%c%L^n\
		\y4. \%c%L^n\
		\y5. \%c%L^n\
		\y6. \%c%L \y(%d|%d)^n\
		7. \%c%L^n\
		\y8. \w%L^n\
		\y9. \%c%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX,
		id, "MB__WORK_WITH_MODELS",
		id, "MB__LINK", g_szBigBuff,
		g_iMenuChar, id, "MB__CHANGE_POS", g_iModel ? g_iModelPos + 1 : 0, g_iModels,
		g_iModelPos ? _W_ : _D_, id, "MB__PREV_MODEL",
		(g_iModelPos < g_iModels - 1) ? _W_ : _D_, id, "MB__NEXT_MODEL",
		g_iMenuChar, id, "MB__MOVE_TO_MODEL",
		g_iMenuChar, id, "MB__CHANGE_VARS",
		g_iMenuChar, id, "MB__CHANGE_MODEL", g_iCachePos + 1, g_iCache,
		g_iMenuChar, id, "MB__LINK_TO_MODES",
		id, "MB__CREATE_NEW_MODEL",
		g_iMenuChar, id, "MB__DELETE_MODEL",
		id, "MB__BACK"
	);

	return func_ShowMenu(id, ALL_KEYS, MENUTYPE__MODEL_MENU)
}

/* -------------------- */

stock func_ModelMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_, _KEY5_: { // Edit current (position / vars)
			if(g_iModel) {
				g_iMenuType = iKey == _KEY1_ ? MENUTYPE__MODEL_SUBMENU_1 : MENUTYPE__MODEL_SUBMENU_2;
				return func_ModelSubMenu(id)
			}
		}
		case _KEY2_: { // Previous
			if(g_iModelPos) {
				func_ChangeElement(--g_iModelPos, ELEMENT_MODEL)
			}
		}
		case _KEY3_: { // Next
			if(g_iModelPos < g_iModels - 1) {
				func_ChangeElement(++g_iModelPos, ELEMENT_MODEL)
			}
		}
		case _KEY4_: {
			func_MoveToElement(g_iModel, MTE__ONLY_Y)
		}
		case _KEY6_: { // Change .mdl/.spr
			if(g_iModel) {
				if(++g_iCachePos == g_iCache) {
					g_iCachePos = 0
				}

				func_GetAndSetModel()

				func_SendAudio(id, SOUND__BLIP1)
			}
		}
		case _KEY7_: { // Link to modes
			if(g_iModel) {
				return func_PromtArgument(id, PROMTMODE__MODE_BIND)
			}
		}
		case _KEY8_: {
			func_CreateElement(ELEMENT_MODEL, ENV_SPRITE, g_iModelPos, g_iModels)
		}
		case _KEY9_: { // Delete current
			if(g_iModel) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_ModelMenu(id)
}

/* -------------------- */

stock func_ModelSubMenu(id) {
	new iKeys

	if(g_iMenuType == MENUTYPE__MODEL_SUBMENU_1) {
		new Float:fAngles[XYZ]

		entity_get_vector(g_iModel, EV_VEC_angles, fAngles)

		formatex( g_szMenu, chx(g_szMenu),
			"%s \y%L^n^n\
			\y1. \w%L \y%c\
			^n      \y2. \w<- %L    \y3. \w-> %L^n^n\
			\y4. \w%L \y%c (%.0f)\
			^n      \y5. \w<- %L    \y6. \w-> %L^n^n\
			\y7. \w%L^n^n\
			\y0. \w%L",

			MENU_TITLE_PREFIX, id, "MB__MODEL_POS_CHANGING",
			id, "MB__CHANGE_AXIS", VEC_CHAR[g_iAxis],
			id, "MB__BACK", id, "MB__FORWARD",
			id, "MB__CHANGE_ANGLE", VEC_CHAR[g_iAngle],	fAngles[g_iAngle],
			id, "MB__BACK", id, "MB__FORWARD",
			id, "MB__CHANGE_STEP", g_fSizeStep,
			id, "MB__BACK"
		);

		iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_0
	}
	else { // -> MENUTYPE__MODEL_SUBMENU_2
		new Float:fColor[XYZ]

		entity_get_vector(g_iModel, EV_VEC_rendercolor, fColor)

		formatex( g_szMenu, chx(g_szMenu),
			"%s \y%L^n^n\
			\y1. \wScale: %.2f^n\
			\y2. \wSequence: %d^n\
			\y3. \wFrame: %.0f^n\
			\y4. \wFramerate: %.2f^n\
			\y5. \wRendermode: %d^n\
			\y6. \wRenderfx: %d^n\
			\y7. \wRenderamt: %.0f^n\
			\y8. \wRendercolor: %.0f %.0f %.0f^n^n\
			\y0. \w%L",

			MENU_TITLE_PREFIX, id, "MB__MODEL_VARS_CHANGING",
			entity_get_float(g_iModel, EV_FL_scale),
			entity_get_int(g_iModel, EV_INT_sequence),
			entity_get_float(g_iModel, EV_FL_frame),
			entity_get_float(g_iModel, EV_FL_framerate),
			entity_get_int(g_iModel, EV_INT_rendermode),
			entity_get_int(g_iModel, EV_INT_renderfx),
			entity_get_float(g_iModel, EV_FL_renderamt),
			fColor[X], fColor[Y], fColor[Z],
			id, "MB__BACK"
		);

		iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0
	}

	return func_ShowMenu(id, iKeys, g_iMenuType)
}

/* -------------------- */

stock func_ModelSubMenu_SubHandler(id, iKey) {
	if(iKey == _KEY0_) {
		return func_ModelMenu(id)
	}

	if(g_iMenuType == MENUTYPE__MODEL_SUBMENU_1) {
		switch(iKey) {
			case _KEY1_: {
				func_ChangeVector(g_iAxis)
			}
			case _KEY2_, _KEY3_: { // Change position
				new Float:fSizeStep = g_fSizeStep / 2.0
				new Float:fOrigin[XYZ]

				entity_get_vector(g_iModel, EV_VEC_origin, fOrigin)
				fOrigin[g_iAxis] += (iKey == _KEY3_) ? fSizeStep : -fSizeStep;
				entity_set_vector(g_iModel, EV_VEC_origin, fOrigin)
			}
			case _KEY4_: {
				func_ChangeVector(g_iAngle)
			}
			case _KEY5_, _KEY6_: {
				func_ChangeAngle(g_iModel, iKey == _KEY5_ ? CA__MINUS : CA__PLUS, g_iAngle)
			}
			case _KEY7_: {
				func_ChangeSizeStep()
			}
		}

		func_SendAudio(id, SOUND__BLIP1)
	}
	else { // -> MENUTYPE__MODEL_SUBMENU_2
		return func_PromtArgument(id, iKey)
	}

	return func_ModelSubMenu(id)
}

/****************************************************************************************
************************************* BUYZONES MENU *************************************
****************************************************************************************/

stock func_BuyZoneMenu(id) {
	func_GetBindedModes_Step1(g_iBuyZone, g_iBuyZone)

	static const TEAM[TEAM_ENUM][] = { "\rTT", "\yCT" }

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n\
		%L \w%s^n^n\
		\y1. \%c%L \y(%d|%d)^n\
		2. \%c%L^n\
		\y3. \%c%L^n\
		\y4. \%c%L^n\
		\y5. \%c%L %s^n\
		\y6. \%c%L^n\
		\y7. \w%L^n\
		\y8. \%c%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__WORK_WITH_BUYZONES",
		id, "MB__LINK", g_szBigBuff,
		g_iMenuChar, id, "MB__CHANGE_SIZE_2", g_iBuyZone ? g_iBuyZonePos + 1 : 0, g_iBuyZones,
		g_iBuyZonePos ? _W_ : _D_, id, "MB__PREV_BUYZONE",
		(g_iBuyZonePos < g_iBuyZones - 1) ? _W_ : _D_, id, "MB__NEXT_BUYZONE",
		g_iMenuChar, id, "MB__MOVE_TO_BUYZONE",
		g_iMenuChar, id, "MB__TEAM_LINK", g_iBuyZone ? TEAM[entity_get_int(g_iBuyZone, ENTVAR__BUYZONE_TEAM_ID)] : NO_VALUE,
		g_iMenuChar, id, "MB__LINK_TO_MODES",
		id, "MB__CREATE_NEW_BUYZONE",
		g_iMenuChar, id, "MB__DELETE_BUYZONE",
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0, MENUTYPE__BUYZONE_MENU)
}

/* -------------------- */

stock func_BuyZoneMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: { // Edit current
			if(g_iBuyZone) {
				return func_BuyZoneSubMenu(id)
			}
		}
		case _KEY2_: { // Previous
			if(g_iBuyZonePos) {
				func_ChangeElement(--g_iBuyZonePos, ELEMENT_BUYZONE)
			}
		}
		case _KEY3_: { // Next
			if(g_iBuyZonePos < g_iBuyZones - 1) {
				func_ChangeElement(++g_iBuyZonePos, ELEMENT_BUYZONE)
			}
		}
		case _KEY4_: {
			func_MoveToElement(g_iBuyZone, MTE__NO_ANGLES)
		}
		case _KEY5_: { // Change team link
			if(g_iBuyZone) {
				new iState = !entity_get_int(g_iBuyZone, ENTVAR__BUYZONE_TEAM_ID)

				entity_set_int(g_iBuyZone, ENTVAR__BUYZONE_TEAM_ID, iState)
				DispatchKeyValue(g_iBuyZone, BZ_TEAM_KEY, iState ? "2" : "1")

				func_SendAudio(id, SOUND__BLIP1)
			}
		}
		case _KEY6_: { // Link to modes
			if(g_iBuyZone) {
				return func_PromtArgument(id, PROMTMODE__MODE_BIND)
			}
		}
		case _KEY7_: {
			func_CreateElement(ELEMENT_BUYZONE, FUNC_BUYZONE, g_iBuyZonePos, g_iBuyZones)
		}
		case _KEY8_: { // Delete
			if(g_iBuyZone) {
				return func_DeleteMenu(id)
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_BuyZoneMenu(id)
}

/* -------------------- */

stock func_BuyZoneSubMenu(id) {
	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n^n\
		\y1. \w%L \y%c\
		^n      \r2. \w<- %L      \r3. \w-> %L\
		^n      \y4. \w<- %L      \y5. \w-> %L^n^n\
		\y6. \w%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__BUYZONE_SIZE_CHANGING",
		id, "MB__CHANGE_SIZE_1", VEC_CHAR[g_iAxis],
		id, "MB__TIGHTER", id, "MB__WIDER",
		id, "MB__TIGHTER", id, "MB__WIDER",
		id, "MB__CHANGE_STEP", g_fSizeStep,
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_0, MENUTYPE__BUYZONE_SUBMENU)
}

/* -------------------- */

stock func_BuyZoneSubMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: {
			func_ChangeVector(g_iAxis)
		}
		case _KEY2_, _KEY3_, _KEY4_, _KEY5_: { // Change size
			if(!func_ChangeSize(g_iBuyZone, iKey)) {
				return func_BuyZoneSubMenu(id)
			}
		}
		case _KEY6_: {
			func_ChangeSizeStep()
		}
		case _KEY0_: {
			return func_BuyZoneMenu(id)
		}
	}

	func_SendAudio(id, SOUND__BLIP1)
	return func_BuyZoneSubMenu(id)
}

/****************************************************************************************
************************************* BOMBSPOTS MENU ************************************
****************************************************************************************/

stock func_BombSpotMenu(id) {
	g_bHasBind = func_GetBindedModes_Step1(g_iBombSpot, g_iBombSpot)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L^n\
		%L \w%s^n^n\
		1. \%c%L \y(%d|%d)^n\
		\y2. \%c%L^n\
		\y3. \w%L^n\
		\y4. \w%L^n\
		\y5. \%c%L^n^n\
		\y0. \w%L",

		MENU_TITLE_PREFIX, id, "MB__WORK_WITH_BOMBSPOTS",
		id, "MB__UNLINK", g_szBigBuff,
		g_iBombSpotPos ? _W_ : _D_, id, "MB__PREV_BOMBSPOT", g_iBombSpotPos + 1, g_iBombSpots,
		(g_iBombSpotPos < g_iBombSpots - 1) ? _W_ : _D_, id, "MB__NEXT_BOMBSPOT",
		id, "MB__MOVE_TO_BOMBSPOT",
		id, "MB__UNLINK_FROM_MODES",
		g_bHasBind ? _W_ : _D_, id, "MB__DELETE_UNLINK",
		id, "MB__BACK"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_0, MENUTYPE__BOMBSPOT_MENU)
}

/* -------------------- */

stock func_BombSpotMenu_SubHandler(id, iKey) {
	switch(iKey) {
		case _KEY1_: { // Previous
			if(g_iBombSpotPos) {
				func_ChangeElement(--g_iBombSpotPos, ELEMENT_BOMBSPOT)
			}
		}
		case _KEY2_: { // Next
			if(g_iBombSpotPos < g_iBombSpots - 1) {
				func_ChangeElement(++g_iBombSpotPos, ELEMENT_BOMBSPOT)
			}
		}
		case _KEY3_: {
			func_MoveToElement(g_iBombSpot, MTE__BRUSH_ORIGIN)
		}
		case _KEY4_: {
			return func_PromtArgument(id, PROMTMODE__MODE_BIND)
		}
		case _KEY5_: { // Delete unlink
			if(g_bHasBind) {
				func_SendAudio(id, SOUND__BLIP1)
				client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__BOMBSPOT_UNLINKED")
				TrieDeleteKey(g_tBinds, func_NumToStr(g_iBombSpot))
			}
		}
		case _KEY0_: {
			return func_MainMenu(id)
		}
	}

	return func_BombSpotMenu(id)
}

/****************************************************************************************
************************************* DELETION MENU *************************************
****************************************************************************************/

stock func_DeleteMenu(id) {
	g_iInputMode = DELETE_MODE

	new iPtr

	switch(g_iMenuType) {
		case MENUTYPE__SPAWN_MENU: iPtr = ELEMENT_SPAWN
		case MENUTYPE__BLOCK_MENU: iPtr = ELEMENT_BLOCK
		case MENUTYPE__MODEL_MENU: iPtr = ELEMENT_MODEL
		case MENUTYPE__BUYZONE_MENU: iPtr = ELEMENT_BUYZONE
		case MENUTYPE__MODE_MENU: iPtr = ELEMENT_MODE
		case MENUTYPE__MAIN_MENU: iPtr = ELEMENT_MODE + 1 // config
	}

	func_GetElementLang(iPtr)

	formatex( g_szMenu, chx(g_szMenu),
		"%s \y%L %L?^n^n\
		1. \r%L^n\
		\y2. \w%L",

		MENU_TITLE_PREFIX, id, "MB__DELETE", id, g_szBigBuff,
		id, "MB__YES_B", id, "MB__NO_B"
	);

	return func_ShowMenu(id, MENU_KEY_1|MENU_KEY_2, g_iMenuType)
}

/* -------------------- */

stock func_DeleteMenu_SubHandler(id, iKey) {
	if(iKey == _KEY1_) {
		switch(g_iMenuType) 	{
			case MENUTYPE__MAIN_MENU: {
				if(delete_file(g_szCfgFile)) {
					func_SendAudio(id, SOUND__BLIP1)
					client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__CFG_DELETED")
				}
				else {
					func_ErrorHandler(ERRORID__CANT_DELETE_CFG)
				}
			}
			case MENUTYPE__SPAWN_MENU: {
				new iLinkedEnt = entity_get_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID)
				new iPos = entity_get_int(iLinkedEnt, ENTVAR__POS_IN_DYNARRAY)

				if(remove_entity(iLinkedEnt)) {
					g_iLinks--

					func_ElementInfo(ELEMENT_SPAWN, ELEMENT_INFO__REMOVE)

					entity_set_int(g_iSpawn, ENTVAR__LINKED_SPAWN_ID, 0)
					entity_set_int(g_iSpawn, EV_INT_sequence, PLAYER_SEQUENCE_UNLINKED)
					func_SetGlowShell(g_iSpawn, COLOR_GREEN)

					func_RemoveElementData(ELEMENT_SPAWN, iPos, g_iSpawn)

					if(iPos < --g_iSpawns) {
						for(new i = iPos; i < g_iSpawns; i++) {
							entity_set_int(ArrayGetCell(Array:g_aArray[ELEMENT_SPAWN], i), ENTVAR__POS_IN_DYNARRAY, i)
						}
					}
				}
				else {
					func_GetElementLang(ELEMENT_SPAWN)
					func_ErrorHandler(ERRORID__CANT_REMOVE_ELEMENT)
				}
			}
			case MENUTYPE__BLOCK_MENU: {
				func_RemoveElement(g_iBlock, ELEMENT_BLOCK, g_iBlockPos, g_iBlocks)
				func_SetCurrBlockSolidType(SOLID_NOT)
			}
			case MENUTYPE__MODEL_MENU: {
				func_RemoveElement(g_iModel, ELEMENT_MODEL, g_iModelPos, g_iModels)
			}
			case MENUTYPE__BUYZONE_MENU: {
				func_RemoveElement(g_iBuyZone, ELEMENT_BUYZONE, g_iBuyZonePos, g_iBuyZones)
			}
			case MENUTYPE__MODE_MENU: {
				ArrayDeleteItem(g_aModeData, g_iModePos)

				new szArg[3], szModeToSet[SM_BUFF_LEN]

				func_GetElementCount()

				for(new a, i, iEnt, iPos, iArg, iLen, iCurrMode = g_iModePos + 1; a < ELEMENT_MODE; a++) {
					if(!g_iElemCount[a]) {
						continue
					}

					for(i = 0; i < g_iElemCount[a]; i++) {
						if(!func_GetBindedModes_Step2((iEnt = ArrayGetCell(g_aArray[a], i)))) {
							continue
						}

						iPos = 0; szModeToSet[0] = EOS; iLen = strlen(g_szBigBuff)

						while(iPos != iLen)	{
							iPos = argparse(g_szBigBuff, iPos, szArg, chx(szArg))

							if((iArg = str_to_num(szArg)) == iCurrMode) {
								continue
							}

							if(iArg > iCurrMode) {
								iArg--
							}

							format(szModeToSet, chx(szModeToSet), "%s %d", szModeToSet, iArg)
						}

						trim(szModeToSet)

						if(szModeToSet[0]) {
							TrieSetString(g_tBinds, func_NumToStr(iEnt), szModeToSet)
						}
						else {
							TrieDeleteKey(g_tBinds, func_NumToStr(iEnt))
						}
					}
				}

				g_iModePos = max(0, g_iModePos - 1)
				g_iModes--

				func_ElementInfo(ELEMENT_MODE, ELEMENT_INFO__REMOVE)
			}
		}
	}

	return func_ToMenuAfterInput(id)
}

/****************************************************************************************
*********************************** MESSAGEMODE-INPUT ***********************************
****************************************************************************************/

stock func_PromtArgument(id, iMode) {
	func_SendAudio(id, SOUND__BLIP1)

	switch(g_iInputMode = iMode) {
		case PROMTMODE__MODE_BIND: {
			client_print_color( id, print_team_red, "^4* ^1%L %L",
				id, "MB__ENTER_MODE_NUMBERS", id, "MB__CANCEL_INFO" );
		}
		case PROMTMODE__MDL_VAR_RENDERCOLOR: {
			client_print_color( id, print_team_red, "^4* ^1%L %L",
				id, "MB__ENTER_RENDERCOLOR", id, "MB__CANCEL_INFO" );
		}
		case PROMTMODE__SET_MODE_NAME: {
			client_print_color( id, print_team_red, "^4* ^1%L %L",
				id, "MB__ENTER_MODE_DESC", id, "MB__CANCEL_INFO" );
		}
		case PROMTMODE__SET_MODE_COLOR:	{
			client_print_color( id, print_team_red, "^4* ^1%L %L",
				id, "MB__ENTER_MODE_COLOR", id, "MB__CANCEL_INFO" );
		}
		default: {
			client_print_color(id, print_team_red, "^4* ^1%L %L", id, "MB__ENTER_VALUE", id, "MB__CANCEL_INFO")
		}
	}

	client_cmd(id, "messagemode ^"mbw_input^"")
	return PLUGIN_HANDLED
}

/* -------------------- */

public clcmd_InputHandler(id) {
	if(id != g_pUser) {
		return PLUGIN_HANDLED
	}

	read_args(g_szBigBuff, chx(g_szBigBuff))
	remove_quotes(g_szBigBuff)
	trim(g_szBigBuff)

	if(g_szBigBuff[0] == '@') {
		return func_ToMenuAfterInput(id)
	}

	func_SendAudio(id, SOUND__BLIP1)
	client_print_color(id, print_team_default, "^4* ^1%L ^"^4%s^1^"", id, "MB__YOU_ENTER", g_szBigBuff)

	if(g_iInputMode == PROMTMODE__MODE_BIND) {
		new iEnt, iMode

		switch(g_iMenuType) {
			case MENUTYPE__SPAWN_MENU: {
				iEnt = g_iSpawn; iMode = ELEMENT_SPAWN
			}
			case MENUTYPE__BLOCK_MENU: {
				iEnt = g_iBlock; iMode = ELEMENT_BLOCK
			}
			case MENUTYPE__MODEL_MENU: {
				iEnt = g_iModel; iMode = ELEMENT_MODEL
			}
			case MENUTYPE__BUYZONE_MENU: {
				iEnt = g_iBuyZone; iMode = ELEMENT_BUYZONE
			}
			case MENUTYPE__BOMBSPOT_MENU: {
				iEnt = g_iBombSpot; iMode = ELEMENT_BOMBSPOT
			}
		}

		if(func_LinkElement(iEnt, g_szBigBuff, iMode)) {
			client_print_color( id, print_team_default, "^4* ^1%L", id,
				g_iMenuType == MENUTYPE__BOMBSPOT_MENU ? "MB__UNLINKING" : "MB__LINKING" );
		}

		return func_ToMenuAfterInput(id)
	}
	//else ->
	if(g_iInputMode > PROMTMODE__MODE_BIND) {
		ArrayGetArray(g_aModeData, g_iModePos, g_eModeData)

		switch(g_iInputMode) {
			case PROMTMODE__SET_MODE_PLAYERS: {
				new iPrevVal, iNextVal = MAX_PLAYERS + 1,
					iEnteredVal = clamp(str_to_num(g_szBigBuff), 1, MAX_PLAYERS);

				if(g_iModePos) {
					ArrayGetArray(g_aModeData, g_iModePos - 1, g_eModeData)
					iPrevVal = g_eModeData[PLAYER_COUNT]
				}

				if(g_iModePos < g_iModes - 1) {
					ArrayGetArray(g_aModeData, g_iModePos + 1, g_eModeData)
					iNextVal = g_eModeData[PLAYER_COUNT]
				}

				ArrayGetArray(g_aModeData, g_iModePos, g_eModeData)

				if(iNextVal >= iEnteredVal >= iPrevVal) {
					g_eModeData[PLAYER_COUNT] = iEnteredVal
				}
				else {
					if(iNextVal == MAX_PLAYERS + 1) {
						iNextVal = MAX_PLAYERS
					}

					func_SendAudio(id, SOUND__ERROR)
					client_print_color(id, print_team_red, "%l", "MB_WRONG_PLCOUNT_VALUE", iPrevVal, iNextVal)
				}
			}
			case PROMTMODE__SET_MODE_NAME: {
				trim(g_szBigBuff)
				g_eModeData[CHAT_DESC] = g_szBigBuff
			}
			case PROMTMODE__SET_MODE_COLOR: {
				new iColor = INVALID_HANDLE

				switch(g_szBigBuff[0]) {
					case 'w': iColor = print_team_grey
					case 'r': iColor = print_team_red
					case 'b': iColor = print_team_blue
					default: iColor = print_team_default
				}

				g_eModeData[CHAT_COLOR] = iColor
			}
			case PROMTMODE__SET_MODE_ROUND_TIME: {
				g_eModeData[ROUND_TIME] = floatmax(0.0, str_to_float(g_szBigBuff))
				func_SetRoundTimeStr()
			}
			case PROMTMODE__SET_MODE_POSTFIX: {
				trim(g_szBigBuff)
				copy(g_eModeData[POSTFIX], chx(g_eModeData[POSTFIX]), g_szBigBuff)
			}
		}

		ArraySetArray(g_aModeData, g_iModePos, g_eModeData)
	}
	else { // g_iInputMode < PROMTMODE__MODE_BIND
		if(g_iInputMode == PROMTMODE__MDL_VAR_SCALE || g_iInputMode == PROMTMODE__MDL_VAR_FRAMERATE) {
			entity_set_float( g_iModel,
				g_iInputMode == PROMTMODE__MDL_VAR_SCALE ? EV_FL_scale : EV_FL_framerate,
					str_to_float(g_szBigBuff) );
		}
		else if(g_iInputMode == PROMTMODE__MDL_VAR_RENDERCOLOR) {
			new Float:fColor[XYZ], szBuffer[RGB][4] // 4 = RGB + 1

			parse( g_szBigBuff, szBuffer[R], chx(szBuffer[]), szBuffer[G], chx(szBuffer[]),
				szBuffer[B], chx(szBuffer[]) );

			for(new i; i < RGB; i++) {
				fColor[i] = str_to_float(szBuffer[i])
			}

			entity_set_vector(g_iModel, EV_VEC_rendercolor, fColor)
		}
		else {
			new iValue = str_to_num(g_szBigBuff)

			switch(g_iInputMode) {
				case PROMTMODE__MDL_VAR_SEQUENCE: entity_set_int(g_iModel, EV_INT_sequence, iValue)
				case PROMTMODE__MDL_VAR_FRAME: entity_set_float(g_iModel, EV_FL_frame, float(iValue))
				case PROMTMODE__MDL_VAR_RENDERMODE: entity_set_int(g_iModel, EV_INT_rendermode, iValue)
				case PROMTMODE__MDL_VAR_RENDERFX: entity_set_int(g_iModel, EV_INT_renderfx, iValue)
				case PROMTMODE__MDL_VAR_RENDERAMT: entity_set_float(g_iModel, EV_FL_renderamt, float(iValue))
			}
		}
	}

	client_print_color(id, print_team_default, "^4* ^1%L", id, "MB__VALUE_CHANGED")
	return func_ToMenuAfterInput(id)
}

/* -------------------- */

stock func_ToMenuAfterInput(id) {
	switch(g_iMenuType) {
		case MENUTYPE__MAIN_MENU: func_MainMenu(id)
		case MENUTYPE__MODE_MENU: func_ModeMenu(id)
		case MENUTYPE__MODE_SUBMENU: func_ModeSubMenu(id)
		case MENUTYPE__SPAWN_MENU: func_SpawnMenu(id)
		case MENUTYPE__BLOCK_MENU: func_BlockMenu(id)
		case MENUTYPE__MODEL_MENU: func_ModelMenu(id)
		case MENUTYPE__MODEL_SUBMENU_2: func_ModelSubMenu(id)
		case MENUTYPE__BUYZONE_MENU: func_BuyZoneMenu(id)
		case MENUTYPE__BOMBSPOT_MENU: func_BombSpotMenu(id)
	}

	return PLUGIN_HANDLED
}

/****************************************************************************************
*************************************** MISCALEOUS **************************************
****************************************************************************************/

public func_Menu_Handler(id, iKey) {
	if(!player_has_access(id)) {
		return PLUGIN_HANDLED
	}

	if(g_iInputMode == DELETE_MODE) {
		g_iInputMode = 0
		return func_DeleteMenu_SubHandler(id, iKey)
	}

	switch(g_iMenuType) {
		case MENUTYPE__MAIN_MENU: func_MainMenu_SubHandler(id, iKey)
		case MENUTYPE__MODE_MENU: func_ModeMenu_SubHandler(id, iKey)
		case MENUTYPE__MODE_SUBMENU: func_ModeSubMenu_SubHandler(id, iKey)
		case MENUTYPE__SPAWN_MENU: func_SpawnMenu_SubHandler(id, iKey)
		case MENUTYPE__BLOCK_MENU: func_BlockMenu_SubHandler(id, iKey)
		case MENUTYPE__BLOCK_SUBMENU: func_BlockSubMenu_SubHandler(id, iKey)
		case MENUTYPE__MODEL_MENU: func_ModelMenu_SubHandler(id, iKey)
		case MENUTYPE__MODEL_SUBMENU_1, MENUTYPE__MODEL_SUBMENU_2: func_ModelSubMenu_SubHandler(id, iKey)
		case MENUTYPE__BUYZONE_MENU: func_BuyZoneMenu_SubHandler(id, iKey)
		case MENUTYPE__BUYZONE_SUBMENU: func_BuyZoneSubMenu_SubHandler(id, iKey)
		case MENUTYPE__BOMBSPOT_MENU: func_BombSpotMenu_SubHandler(id, iKey)
	}

	return PLUGIN_HANDLED
}

/* -------------------- */

stock func_ShowMenu(id, iKeys, iMenuType) {
#if defined MENU_FIX
	set_pdata_int(id, m_iMenu, 0)
#endif
	g_iMenuType = iMenuType
	show_menu(id, iKeys, g_szMenu, -1, MENU_IDENT_STRING__MBW)
	return PLUGIN_HANDLED
}

/* -------------------- */

stock func_OverCurrMode() {
	if(g_iMenuType == MENUTYPE__SPAWN_MENU) {
		func_ToggleSpawnsVisibility(SET_INVISIBLE)
	}
	else if(g_iMenuType > MENUTYPE__SPAWN_MENU) {
		remove_task(TASKID__BOX_LINES)
	}

	if(MENUTYPE__MODEL_MENU > g_iMenuType > MENUTYPE__SPAWN_MENU) {
		func_SetCurrBlockSolidType(SOLID_BBOX)
	}
}

/* -------------------- */

bool:func_GetBindedModes_Step1(iIsPos, iEnt) {
	g_iMenuChar = iEnt ? _W_ : _D_;

	if(!iIsPos || !func_GetBindedModes_Step2(iEnt))	{
		g_szBigBuff = NO_VALUE
		return false
	}

	return true
}

/* -------------------- */

bool:func_GetBindedModes_Step2(iEnt) {
	return TrieGetString(g_tBinds, func_NumToStr(iEnt), g_szBigBuff, chx(g_szBigBuff))
}

/* -------------------- */

bool:func_LinkElement(iEnt, szBuffer[], iPtr) {
	static szArg[3], szModeToSet[SM_BUFF_LEN]; szModeToSet[0] = EOS

	new iPos, iArg, bool:bError, iLen = strlen(szBuffer)

	while(iPos != iLen)	{
		iPos = argparse(szBuffer, iPos, szArg, chx(szArg))
		iArg = str_to_num(szArg)

		if(iArg < MIN_MODE_VALUE[iPtr] || iArg > g_iModes) {
			if(!g_pUser) {
				func_InitError()

				log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
					LANG_SERVER, "MB__CANT_BIND_TO_UNDEFINED_MODE", iArg );

				continue
			}
			//else ->
			bError = true

			continue
		}

		format(szModeToSet, chx(szModeToSet), "%s %d", szModeToSet, iArg)
	}

	trim(szModeToSet)

	if(szModeToSet[0]) {
		TrieSetString(g_tBinds, func_NumToStr(iEnt), szModeToSet)
	}
	else {
		TrieDeleteKey(g_tBinds, func_NumToStr(iEnt))
	}

	if(bError) {
		func_ErrorHandler(ERRORID__UNDEF_MODE_DETECTED)
		return false
	}

	return true
}

/* -------------------- */

stock func_MakeSpawns() {
	g_bHaveSpawns = true

	new const MSE_NAME[] = "Map Spawns Editor"

	for(new i, iCount = get_pluginsnum(); i < iCount; i++) {
		get_plugin(i, g_szBigBuff, chx(g_szBigBuff), g_szSmBuff, chx(g_szSmBuff))

		if(g_szSmBuff[0] == 'M' && equali(g_szSmBuff, MSE_NAME)) {
			if(pause("cd", g_szBigBuff) && g_pUser) {
				client_print_color( g_pUser, print_team_blue, "^4* ^3%s ^1%L",
					MSE_NAME, g_pUser, "MB__MSE_STOPPED" );
			}

			break
		}
	}

	/* --- */

	new const szSpawnClassName[][] = { "info_player_deathmatch", "info_player_start" }

	for(new iTeam, iEnt, iSpawnEnt, iErrNum, Float:fOrigin[XYZ], Float:fAngles[XYZ]; iTeam < TEAM_ENUM; iTeam++) {
		iEnt = MaxClients

		while((iEnt = find_ent_by_class(iEnt, szSpawnClassName[iTeam]))) {
			entity_get_vector(iEnt, EV_VEC_origin, fOrigin)
			entity_get_vector(iEnt, EV_VEC_angles, fAngles)

			iSpawnEnt = func_MakeSpawn(iTeam, fOrigin, fAngles)

			if(iSpawnEnt) {
				entity_set_int(iSpawnEnt, ENTVAR__MDL_ID_TO_LINK, iTeam + TEAM_ENUM)
				g_iSpawns++
				continue
			}

			iErrNum++
		}

		if(iErrNum) {
			if(g_pUser) {
				func_ErrorHandler(ERRORID__SOME_SPAWN_UNINITIALIZED, iErrNum)
			}
			else {
				func_InitError()
				log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__SOME_SPAWN_UNINITIALIZED", iErrNum)
			}
		}
	}
}

/* -------------------- */

stock func_MakeSpawn(iModelID, Float:fOrigin[XYZ], Float:fAngles[XYZ]) {
	new iEnt = create_entity(INFO_TARGET)

	if(iEnt) {
		entity_set_string(iEnt, EV_SZ_classname, MBW_SPAWN_CLASSNAME)
		entity_set_model(iEnt, SPAWN_MODEL[iModelID])
		entity_set_origin(iEnt, fOrigin)
		entity_set_vector(iEnt, EV_VEC_angles, fAngles)
		entity_set_int(iEnt, EV_INT_sequence, PLAYER_SEQUENCE_UNLINKED)
		ArrayPushCell(Array:g_aArray[ELEMENT_SPAWN], iEnt)
	}

	return iEnt
}

/* -------------------- */

stock func_ToggleSpawnsVisibility(bool:bMode) {
	for(new i, iEnt; i < g_iSpawns; i++) {
		iEnt = ArrayGetCell(Array:g_aArray[ELEMENT_SPAWN], i)
		set_entity_visibility(iEnt, bMode)
	}
}

/* -------------------- */

stock func_GetModeData(iPos) {
	ArrayGetArray(g_aModeData, iPos, g_eModeData)
}

/* -------------------- */

stock func_GetSpawnByAim() {
	new Float:fStartOrigin[XYZ], Float:fViewAgle[XYZ], Float:fEndOrigin[XYZ]

	entity_get_vector(g_pUser, EV_VEC_origin, fStartOrigin)
	entity_get_vector(g_pUser, EV_VEC_v_angle, fViewAgle)

	fStartOrigin[Z] += 10.0

	for(new i, iEntList[1]; i <= 1000; i += 20) {
		func_GetVectorByAngle(fStartOrigin, fViewAgle, float(i), fEndOrigin)

		if(find_sphere_class(0, MBW_SPAWN_CLASSNAME, 20.0, iEntList, sizeof(iEntList), fEndOrigin)) {
			return iEntList[0]
		}
	}

	return 0
}

/* -------------------- */

stock func_GetVectorByAngle(Float:fStartOrigin[XYZ], Float:fViewAgle[XYZ], Float:fMul, Float:fEndOrigin[XYZ]) {
   angle_vector(fViewAgle, ANGLEVECTOR_FORWARD, fEndOrigin)
   fEndOrigin[X] = fEndOrigin[X] * fMul + fStartOrigin[X]
   fEndOrigin[Y] = fEndOrigin[Y] * fMul + fStartOrigin[Y]
   fEndOrigin[Z] = fEndOrigin[Z] * fMul + fStartOrigin[Z]
}

/* -------------------- */

stock func_SetGlowShell(iEnt, iPtr) {
	entity_set_int(iEnt, EV_INT_renderfx, kRenderFxGlowShell)
	entity_set_vector(iEnt, EV_VEC_rendercolor, GLOW_COLOR[iPtr])
	entity_set_float(iEnt, EV_FL_renderamt, 50.0)
}

/* -------------------- */

stock func_RemoveGlowShell(iEnt) {
	entity_set_int(iEnt, EV_INT_renderfx, kRenderFxNone)
}

/* -------------------- */

stock func_GetNormalizedVec(Float:fOrigin[XYZ], Float:fAngles[XYZ]) {
	entity_get_vector(g_pUser, EV_VEC_origin, fOrigin)
	entity_get_vector(g_pUser, EV_VEC_angles, fAngles)

	for(new i; i < XYZ; i++) {
		fOrigin[i] -= floatfract(fOrigin[i])
	}

	fAngles[X] = fAngles[Z] = 0.0

	if((fAngles[Y] -= floatfract(fAngles[Y])) < 0.0) {
		fAngles[Y] = MAX_ANGLE - -fAngles[Y]
	}
}

/* -------------------- */

stock func_CreateAndLinkOffset(iEnt, Float:fOrigin[XYZ], Float:fAngles[XYZ]) {
	new iLinkedEnt = func_MakeSpawn(entity_get_int(iEnt, ENTVAR__MDL_ID_TO_LINK), fOrigin, fAngles)

	if(iLinkedEnt) {
		g_iLinks++
		entity_set_int(iEnt, EV_INT_sequence, PLAYER_SEQUENCE_LINKED)
		entity_set_int(iEnt, ENTVAR__LINKED_SPAWN_ID, iLinkedEnt)
		entity_set_int(iLinkedEnt, ENTVAR__LINKED_SPAWN_ID, iEnt)
		entity_set_int(iLinkedEnt, ENTVAR__POS_IN_DYNARRAY, g_iSpawns++)
	}

	return iLinkedEnt
}

/* -------------------- */

stock func_CreateElement(iElementType, const szClassName[], &iPos, &iCount, Float:fOrigin[XYZ] = {0.0, 0.0, 0.0}, Float:fAngles[XYZ] = {0.0, 0.0, 0.0}) {
	new iEnt = create_entity(szClassName)

	if(!iEnt) {
		func_GetElementLang(iElementType)

		if(g_pUser) {
			func_ErrorHandler(ERRORID__CANT_SET_ELEMENT)
		}
		else {
			func_InitError()

			log_to_file( g_szErrorLog, "%L %L", LANG_SERVER, "MB__STRING_PTR", g_iStrPos,
				LANG_SERVER, "MB__CANT_SET_ELEMENT", LANG_SERVER, "MB__CREATE_S", LANG_SERVER, g_szBigBuff );
		}
	}
	else {
		if(g_pUser) {
			func_GetNormalizedVec(fOrigin, fAngles)
		}

		switch(iElementType) {
			case ELEMENT_BLOCK: {
				func_SetCurrBlockSolidType(SOLID_BBOX)
				g_iBlock = iEnt

				entity_set_string(g_iBlock, EV_SZ_classname, MBW_BLOCK_CLASSNAME)
				entity_set_model(g_iBlock, BLOCK_MODEL)
				entity_set_origin(g_iBlock, fOrigin)
				entity_set_vector(g_iBlock, EV_VEC_angles, fAngles)
				entity_set_int(g_iBlock, EV_INT_movetype, MOVETYPE_FLY)
				entity_set_size(g_iBlock, BLOCK_MINS, BLOCK_MAXS)

				if(!g_bBlockModels) {
					set_entity_visibility(g_iBlock, 0)
				}
			}
			case ELEMENT_MODEL: {
				g_iModel = iEnt

				func_GetAndSetModel()
				entity_set_float(g_iModel, EV_FL_framerate, 1.0)
				DispatchSpawn(g_iModel)
				entity_set_float(g_iModel, EV_FL_framerate, 0.0)
				entity_set_origin(g_iModel, fOrigin)
				entity_set_vector(g_iModel, EV_VEC_angles, fAngles)
				entity_set_float(g_iModel, EV_FL_scale, DEFAULT_SCALE)
				entity_set_float(g_iModel, EV_FL_renderamt, DEFAULT_RENDERAMT)
			}
			case ELEMENT_BUYZONE: {
				g_iBuyZone = iEnt
				DispatchKeyValue(g_iBuyZone, BZ_TEAM_KEY, "1")
				DispatchSpawn(g_iBuyZone)
				entity_set_origin(g_iBuyZone, fOrigin)
				entity_set_size(g_iBuyZone, BUYZONE_MINS, BUYZONE_MAXS)
			}
		}

		entity_set_int(iEnt, ENTVAR__POS_IN_DYNARRAY, iPos = iCount++)
		ArrayPushCell(Array:g_aArray[iElementType], iEnt)

		if(g_pUser) {
			func_ElementInfo(iElementType)
		}
	}

	return iEnt
}

/* -------------------- */

stock func_RemoveElement(&iEnt, iArrayIndex, &iListPos, &iTotalElements) {
	new iPos = entity_get_int(iEnt, ENTVAR__POS_IN_DYNARRAY)

	if(remove_entity(iEnt)) {
		func_ElementInfo(iArrayIndex, ELEMENT_INFO__REMOVE)

		func_RemoveElementData(iArrayIndex, iPos, iEnt)

		iListPos = max(0, iListPos - 1)

		if(--iTotalElements) {
			iEnt = ArrayGetCell(g_aArray[iArrayIndex], iListPos)

			if(iPos < iTotalElements) {
				for(new i = iPos; i < iTotalElements; i++) {
					entity_set_int(ArrayGetCell(g_aArray[iArrayIndex], i), ENTVAR__POS_IN_DYNARRAY, i)
				}
			}
		}
		else {
			iEnt = 0
		}
	}
	else {
		func_GetElementLang(iArrayIndex)
		func_ErrorHandler(ERRORID__CANT_REMOVE_ELEMENT)
	}
}

/* -------------------- */

stock func_RemoveElementData(iArrayIndex, iPos, iEnt) {
	ArrayDeleteItem(g_aArray[iArrayIndex], iPos)
	TrieDeleteKey(g_tBinds, func_NumToStr(iEnt))
}

/* -------------------- */

stock func_GetElementLang(iPtr) {
	formatex(g_szBigBuff, chx(g_szBigBuff), "MB__ELEMENT_%d", iPtr + 1)
}

/* -------------------- */

stock func_GetElementCount() {
	g_iElemCount[ELEMENT_SPAWN] = g_iSpawns
	g_iElemCount[ELEMENT_BLOCK] = g_iBlocks
	g_iElemCount[ELEMENT_MODEL] = g_iModels
	g_iElemCount[ELEMENT_BUYZONE] = g_iBuyZones
	g_iElemCount[ELEMENT_BOMBSPOT] = g_iBombSpots
}

/* -------------------- */

stock func_ElementInfo(iArrayIndex, bool:bType = true) {
	func_SendAudio(g_pUser, SOUND__BLIP1)

	func_GetElementLang(iArrayIndex)

	client_print_color( g_pUser, print_team_default, "^4* ^1%L",
		g_pUser, "MB__ELEMENT_INFO", g_pUser, g_szBigBuff, g_pUser, bType ? "MB__CREATED_S" : "MB__DELETED_S" );
}

/* -------------------- */

bool:func_ChangeSize(iEnt, iKey) {
	new Float:fOrigin[XYZ], Float:fMins[XYZ], Float:fMaxs[XYZ]

	entity_get_vector(iEnt, EV_VEC_origin, fOrigin)
	entity_get_vector(iEnt, EV_VEC_mins, fMins)
	entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)

	if(
		(iKey == _KEY2_ || iKey == _KEY4_)
			&&
		((floatabs(fMins[g_iAxis]) + fMaxs[g_iAxis]) < g_fSizeStep + 1.0)
	) {
		func_SendAudio(g_pUser, SOUND__ERROR)
		return false
	}

	new Float:fSizeStep = g_fSizeStep / 2.0

	switch(iKey) {
		case _KEY2_: {
			fMins[g_iAxis] += fSizeStep
			fMaxs[g_iAxis] -= fSizeStep
			fOrigin[g_iAxis] += fSizeStep
		}
		case _KEY3_: {
			fMins[g_iAxis] -= fSizeStep
			fMaxs[g_iAxis] += fSizeStep
			fOrigin[g_iAxis] -= fSizeStep
		}
		case _KEY4_: {
			fMins[g_iAxis] += fSizeStep
			fMaxs[g_iAxis] -= fSizeStep
			fOrigin[g_iAxis] -= fSizeStep
		}
		case _KEY5_: {
			fMins[g_iAxis] -= fSizeStep
			fMaxs[g_iAxis] += fSizeStep
			fOrigin[g_iAxis] += fSizeStep
		}
	}

	entity_set_origin(iEnt, fOrigin)
	entity_set_size(iEnt, fMins, fMaxs)
	return true
}

/* -------------------- */

stock func_ChangeAngle(iEnt, iMode, iAxis) {
	new Float:fAngles[XYZ]

	entity_get_vector(iEnt, EV_VEC_angles, fAngles)

	fAngles[iAxis] += (iMode == CA__PLUS) ? g_fSizeStep : -g_fSizeStep;

	if(fAngles[iAxis] >= MAX_ANGLE) {
		fAngles[iAxis] -= MAX_ANGLE
	}
	else if(fAngles[iAxis] < 0.0) {
		fAngles[iAxis] += MAX_ANGLE
	}

	entity_set_vector(iEnt, EV_VEC_angles, fAngles)
}

/* -------------------- */

stock func_ChangeVector(&iVector) {
	if(++iVector > VECTOR_Z) {
		iVector = VECTOR_X
	}
}

/* -------------------- */

stock func_ChangeSizeStep() {
	g_fSizeStep = (g_fSizeStep < 100.0) ? g_fSizeStep * 10.0 : 1.0
}

/* -------------------- */

stock func_MoveToElement(iEnt, iMode) {
	if(!iEnt) {
		return
	}

	func_SendAudio(g_pUser, SOUND__BLIP1)

	new Float:fOrigin[XYZ]

	entity_get_vector(iEnt, EV_VEC_origin, fOrigin)

	if(iMode == MTE__BRUSH_ORIGIN && origin_is_null(fOrigin)) {
		new Float:fMins[XYZ], Float:fMaxs[XYZ]
		entity_get_vector(iEnt, EV_VEC_mins, fMins)
		entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)
		func_GetBrushEntOrigin(fMins, fMaxs, fOrigin)
	}

	entity_set_origin(g_pUser, fOrigin)
	entity_set_vector(g_pUser, EV_VEC_velocity, NULL_VECTOR)

	if(iMode > MTE__ONLY_Y) { // MTE__NO_ANGLES / MTE__BRUSH_ORIGIN
		return
	}

	new Float:fAngles[XYZ]

	entity_get_vector(iEnt, EV_VEC_angles, fAngles)

	if(iMode == MTE__ONLY_Y) {
		fAngles[X] = fAngles[Z] = 0.0
	}

	entity_set_vector(g_pUser, EV_VEC_angles, fAngles)
	entity_set_int(g_pUser, EV_INT_fixangle, 1)
}

/* -------------------- */

func_SetCurrBlockSolidType(iType) {
	if(g_iBlock && g_bBlockSolid) {
		entity_set_int(g_iBlock, EV_INT_solid, iType)
	}
}

/* -------------------- */

stock func_ToggleBlockOpt(iState, bool:bMode) {
	func_SendAudio(g_pUser, SOUND__BLIP1)

	if(!g_iBlocks) {
		return
	}

	for(new i, iEnt; i < g_iBlocks; i++) {
		iEnt = ArrayGetCell(Array:g_aArray[ELEMENT_BLOCK], i)

		if(bMode/* == TBO__MODELS */) {
			set_entity_visibility(iEnt, iState)
			continue
		}
		//else -> TBO__SOLID
		if(iEnt != g_iBlock) {
			entity_set_int(iEnt, EV_INT_solid, iState)
		}
	}
}

/* -------------------- */

stock func_ChangeBlock(iPos) {
	if(g_bBlockSolid) {
		entity_set_int(g_iBlock, EV_INT_solid, SOLID_BBOX)
	}

	func_ChangeElement(iPos, ELEMENT_BLOCK)
	entity_set_int(g_iBlock, EV_INT_solid, SOLID_NOT)
}

/* -------------------- */

stock func_ChangeElement(iPos, iType) {
	new iEnt = ArrayGetCell(g_aArray[iType], iPos)

	switch(iType) {
		case ELEMENT_BLOCK: g_iBlock = iEnt
		case ELEMENT_MODEL: g_iModel = iEnt
		case ELEMENT_BUYZONE: g_iBuyZone = iEnt
		case ELEMENT_BOMBSPOT: g_iBombSpot = iEnt
	}
}

/* -------------------- */

bool:func_UnSafeRange(Float:fOrigin[XYZ], Float:fAngles[XYZ], iLinkedEnt) {
	new Float:fViewAgle[XYZ], Float:fEndOrigin[XYZ], Float:fTraceEndOrigin[XYZ]

	fViewAgle = fAngles

	new iEntList[10], bool:bUnSafe

	for(new i, Float:fMul = SAFEp2w * 2.0; i < 360; i += 10) {
		fViewAgle[Y] = float(i)
		func_GetVectorByAngle(fOrigin, fViewAgle, fMul, fEndOrigin)
		trace_line(-1, fOrigin, fEndOrigin, fTraceEndOrigin)

		if(vector_distance(fOrigin, fTraceEndOrigin) < SAFEp2w) {
			func_MakeBeamPoints(fOrigin, fTraceEndOrigin, g_iBeamSprID, 2, UNSAFE_BEAM_COLOR, UNSAFE_BEAM_BRIGHTNESS)
			bUnSafe = true
		}
	}

	if(!g_bRangeCheck) {
		return bUnSafe
	}

	new iCount = find_sphere_class(0, MBW_SPAWN_CLASSNAME, SAFEp2p * 1.5, iEntList, sizeof(iEntList), fOrigin)

	for(new i, iEnt; i < iCount; i++) {
		iEnt = iEntList[i]

		if(iEnt == iLinkedEnt || iEnt == g_iSpawn) {
			continue
		}

		entity_get_vector(iEnt, EV_VEC_origin, fEndOrigin)

		if(vector_distance(fOrigin, fEndOrigin) < SAFEp2p) {
			func_MakeBeamPoints(fOrigin, fEndOrigin, g_iBeamSprID, 5, UNSAFE_BEAM_COLOR, UNSAFE_BEAM_BRIGHTNESS)
			bUnSafe = true
		}
	}

	return bUnSafe
}

/* -------------------- */

stock func_SetHighlightTask(iMode) {
	g_iHighlightMode = iMode
	set_task(0.2, "task_HighlightElement", TASKID__BOX_LINES, .flags = "b")
}

/* -------------------- */

public task_HighlightElement() {
	new iEnt

	switch(g_iMenuType)	{
		case MENUTYPE__BLOCK_MENU, MENUTYPE__BLOCK_SUBMENU: iEnt = g_iBlock
		case MENUTYPE__MODEL_MENU, MENUTYPE__MODEL_SUBMENU_1, MENUTYPE__MODEL_SUBMENU_2: iEnt = g_iModel
		case MENUTYPE__BUYZONE_MENU, MENUTYPE__BUYZONE_SUBMENU: iEnt = g_iBuyZone
		case MENUTYPE__BOMBSPOT_MENU: iEnt = g_iBombSpot
	}

	if(!iEnt) {
		return
	}

	new bool:bNoOrigin

	static Float:fEntOrigin[XYZ], Float:fUserOrigin[XYZ], Float:fMins[XYZ], Float:fMaxs[XYZ]

	entity_get_vector(iEnt, EV_VEC_origin, fEntOrigin)
	entity_get_vector(iEnt, EV_VEC_mins, fMins)
	entity_get_vector(iEnt, EV_VEC_maxs, fMaxs)

	if(g_iHighlightMode == HIGHLIGHT__NO_SIDE_LINES && (bNoOrigin = origin_is_null(fEntOrigin))) {
		func_GetBrushEntOrigin(fMins, fMaxs, fEntOrigin)
	}

	entity_get_vector(g_pUser, EV_VEC_origin, fUserOrigin)
	fUserOrigin[Z] -= 16.0

	func_DrawLine( fUserOrigin[X], fUserOrigin[Y], fUserOrigin[Z],
		fEntOrigin[X], fEntOrigin[Y], fEntOrigin[Z], BOX_LINE_COLOR_MAIN );

	if(g_iHighlightMode == HIGHLIGHT__ONLY_BEAM) {
		return
	}

	if(g_iHighlightMode == HIGHLIGHT__FULL || !bNoOrigin) {
		fMins[X] += fEntOrigin[X]
		fMins[Y] += fEntOrigin[Y]
		fMins[Z] += fEntOrigin[Z]
		fMaxs[X] += fEntOrigin[X]
		fMaxs[Y] += fEntOrigin[Y]
		fMaxs[Z] += fEntOrigin[Z]
	}

	func_DrawLine(fMaxs[X], fMaxs[Y], fMaxs[Z], fMins[X], fMaxs[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMaxs[X], fMaxs[Y], fMaxs[Z], fMaxs[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMaxs[X], fMaxs[Y], fMaxs[Z], fMaxs[X], fMaxs[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMins[Y], fMins[Z], fMaxs[X], fMins[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMins[Y], fMins[Z], fMins[X], fMaxs[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMins[Y], fMins[Z], fMins[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMaxs[Y], fMaxs[Z], fMins[X], fMaxs[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMaxs[Y], fMins[Z], fMaxs[X], fMaxs[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMaxs[X], fMaxs[Y], fMins[Z], fMaxs[X], fMins[Y], fMins[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMaxs[X], fMins[Y], fMins[Z], fMaxs[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMaxs[X], fMins[Y], fMaxs[Z], fMins[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)
	func_DrawLine(fMins[X], fMins[Y], fMaxs[Z], fMins[X], fMaxs[Y], fMaxs[Z], BOX_LINE_COLOR_MAIN)

	if(g_iHighlightMode == HIGHLIGHT__NO_SIDE_LINES) {
		return
	}

	if(g_iAxis == VECTOR_X) {
		func_DrawLine(fMaxs[X], fMaxs[Y], fMaxs[Z], fMaxs[X], fMins[Y], fMins[Z], BOX_LINE_COLOR_YELLOW)
		func_DrawLine(fMaxs[X], fMaxs[Y], fMins[Z], fMaxs[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_YELLOW)
		func_DrawLine(fMins[X], fMaxs[Y], fMaxs[Z], fMins[X], fMins[Y], fMins[Z], BOX_LINE_COLOR_RED)
		func_DrawLine(fMins[X], fMaxs[Y], fMins[Z], fMins[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_RED)
		return
	}
	if(g_iAxis == VECTOR_Y)	{
		func_DrawLine(fMins[X], fMins[Y], fMins[Z], fMaxs[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_RED)
		func_DrawLine(fMaxs[X], fMins[Y], fMins[Z], fMins[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_RED)
		func_DrawLine(fMins[X], fMaxs[Y], fMins[Z], fMaxs[X], fMaxs[Y], fMaxs[Z], BOX_LINE_COLOR_YELLOW)
		func_DrawLine(fMaxs[X], fMaxs[Y], fMins[Z], fMins[X], fMaxs[Y], fMaxs[Z], BOX_LINE_COLOR_YELLOW)
		return
	}
	if(g_iAxis == VECTOR_Z)	{
		func_DrawLine(fMaxs[X], fMaxs[Y], fMaxs[Z], fMins[X], fMins[Y], fMaxs[Z], BOX_LINE_COLOR_YELLOW)
		func_DrawLine(fMaxs[X], fMins[Y], fMaxs[Z], fMins[X], fMaxs[Y], fMaxs[Z], BOX_LINE_COLOR_YELLOW)
		func_DrawLine(fMaxs[X], fMaxs[Y], fMins[Z], fMins[X], fMins[Y], fMins[Z], BOX_LINE_COLOR_RED)
		func_DrawLine(fMaxs[X], fMins[Y], fMins[Z], fMins[X], fMaxs[Y], fMins[Z], BOX_LINE_COLOR_RED)
	}
}

/* -------------------- */

stock func_DrawLine(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, const iColor[RGB]) {
	static Float:fStartOrigin[XYZ], Float:fEndOrigin[XYZ]

	fStartOrigin[X] = x1; fStartOrigin[Y] = y1; fStartOrigin[Z] = z1
	fEndOrigin[X] = x2; fEndOrigin[Y] = y2; fEndOrigin[Z] = z2

	func_MakeBeamPoints(fStartOrigin, fEndOrigin, g_iBoxSprID, BOX_LINE_WIDTH, iColor, BOX_LINE_BRIGHTNESS)
}

/* -------------------- */

stock func_MakeBeamPoints(Float:fVec1[XYZ], Float:fVec2[XYZ], iSprID, iWidth, const iColor[RGB], iBrightness) {
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = g_pUser)
	write_byte(TE_BEAMPOINTS)
	write_coord_f(fVec1[X])
	write_coord_f(fVec1[Y])
	write_coord_f(fVec1[Z])
	write_coord_f(fVec2[X])
	write_coord_f(fVec2[Y])
	write_coord_f(fVec2[Z])
	write_short(iSprID)
	write_byte(1) // starting frame
	write_byte(0) // frame rate in 0.1's
	write_byte(4) // life in 0.1's
	write_byte(iWidth)
	write_byte(0) // noise amplitude in 0.01's
	write_byte(iColor[R]) // R
	write_byte(iColor[G]) // G
	write_byte(iColor[B]) // B
	write_byte(iBrightness) // brightness
	write_byte(0) // scroll speed in 0.1's
	message_end()
}

/* -------------------- */

stock func_GetAndSetModel() {
	ArrayGetString(g_aCache, g_iCachePos, g_szBigBuff, chx(g_szBigBuff))
	entity_set_model(g_iModel, g_szBigBuff)
	entity_set_int(g_iModel, ENTVAR__MDL_ID_TO_LINK, g_iCachePos + 1)
}

/* -------------------- */

public func_ClCmdNoClip(id) {
	if(id == g_pUser && is_user_alive(id)) {
		new bool:bHas = (entity_get_int(id, EV_INT_movetype) == MOVETYPE_NOCLIP)

		entity_set_int(id, EV_INT_movetype, bHas ? MOVETYPE_WALK : MOVETYPE_NOCLIP)
		func_SendAudio(id, SOUND__BLIP1)

		client_print_color( id, print_team_red, "^4* ^1%L", id,
			bHas ? "MB__NOCLIP_DEACTIVATED" : "MB__NOCLIP_ACTIVATED" );

		entity_set_float(id, EV_FL_maxspeed, bHas ? 250.0 : 400.0) // not accurate, i know

		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

/* -------------------- */

public engfwd_Touch(iTouchedEnt, iToucherEnt) {
	if(is_valid_ent(iTouchedEnt) && is_valid_ent(iToucherEnt)) {
		static Float:fAngles[XYZ], Float:fVelocity[XYZ]

		entity_get_vector(iToucherEnt, EV_VEC_angles, fAngles)
		angle_vector(fAngles, ANGLEVECTOR_FORWARD, fVelocity)

		xs_vec_mul_scalar(fVelocity, STRONG_PUSH, fVelocity)

		/*fVelocity[X] *= STRONG_PUSH
		fVelocity[Y] *= STRONG_PUSH
		fVelocity[Z] *= STRONG_PUSH*/

		entity_set_vector(iTouchedEnt, EV_VEC_velocity, fVelocity)
	}
}

/* -------------------- */

public client_disconnected(id) {
	if(id == g_pUser) {
		func_OverCurrMode()
		g_pUser = g_iMenuType = 0
	}
}

/* -------------------- */

bool:origin_is_null(Float:fOrigin[XYZ]) {
	return !(fOrigin[X] || fOrigin[Y] || fOrigin[Z])
}

/* -------------------- */

stock func_GetBrushEntOrigin(Float:fMins[XYZ], Float:fMaxs[XYZ], Float:fOrigin[XYZ]) {
	fOrigin[X] = (fMins[X] + fMaxs[X]) * 0.5
	fOrigin[Y] = (fMins[Y] + fMaxs[Y]) * 0.5
	fOrigin[Z] = (fMins[Z] + fMaxs[Z]) * 0.5
}

/* -------------------- */

stock func_NumToStr(iNum) {
	new szStr[5]
	formatex(szStr, chx(szStr), "%d", iNum)
	return szStr
}

/* -------------------- */

stock player_has_access(id) {
	return (get_user_flags(id) & ACCESS_FLAG)
}

/* -------------------- */

func_InitError() {
	if(!g_bHaveError) {
		g_bHaveError = true
		log_to_file(g_szErrorLog, "%L", LANG_SERVER, "MB__INIT_ERROR", g_szMapName)
	}
}

/* -------------------- */

stock func_ErrorHandler(iMode, iVal = 0) {
	func_SendAudio(g_pUser, SOUND__ERROR)

	switch(iMode) {
		case ERRORID__SOMETHING_WRONG: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__SOMETHING_WRONG")
		}
		case ERRORID__PRECACHE_IS_EMPTY: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__PRECACHE_IS_EMPTY")
		}
		case ERRORID__NO_BOMBSPOTS: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__NO_BOMBSPOTS")
		}
		case ERRORID__CANT_WRITE_TO_CFG: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__CANT_WRITE_CFG")
		}
		case ERRORID__UNBINDED_ELEMENT_DETECTED: {
			client_print_color( g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__UNBINDED_ELEMENT_DETECTED")
		}
		case ERRORID__MODE_LIMIT_REACHED: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__MODE_LIMIT_REACHED")
		}
		case ERRORID__SPAWN_UNRECOGNIZED: {
			client_print(g_pUser, print_center, "*** %L ***", g_pUser, "MB__SPAWN_UNRECOGNIZED")
		}
		case ERRORID__UNSAFE_RANGE: {
			client_print(g_pUser, print_center, "*** %L ***", g_pUser, "MB__UNSAFE_POS")
		}
		case ERRORID__CANT_SET_ELEMENT, ERRORID__CANT_REMOVE_ELEMENT: {
			client_print_color( g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__CANT_SET_ELEMENT",
				g_pUser, iMode == ERRORID__CANT_SET_ELEMENT ? "MB__CREATE_S" : "MB__DELETE_S",
				g_pUser, g_szBigBuff );
		}
		case ERRORID__CANT_DELETE_CFG:	{
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__CANT_DELETE_CFG")
		}
		case ERRORID__SOME_SPAWN_UNINITIALIZED:	{
			client_print_color( g_pUser, print_team_red,
				"^3* ^1%L", g_pUser, "MB__SOME_SPAWN_UNINITIALIZED", iVal );
		}
		case ERRORID__UNDEF_MODE_DETECTED: {
			client_print_color(g_pUser, print_team_red, "^3* ^1%L", g_pUser, "MB__UNDEF_MODE_DETECTED")
		}
	}
}

/* -------------------- */

stock func_SendAudio(id, const szSample[]) {
	message_begin(MSG_ONE_UNRELIABLE, g_msgSendAudio, .player = id)
	write_byte(id)
	write_string(szSample)
	write_short(PITCH_NORM)
	message_end()
}

/* -------------------- */

public plugin_end() {
	if(g_aCache) {
		ArrayDestroy(g_aCache)
	}

	if(g_aModeData) {
		ArrayDestroy(g_aModeData)

		for(new i; i < sizeof(g_aArray); i++) {
			ArrayDestroy(g_aArray[i])
		}

		TrieDestroy(g_tBinds)
	}
}