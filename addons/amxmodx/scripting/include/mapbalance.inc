#define MAX_MODEL_PATH_LENGTH 96
#define MAX_MODE_NAME_LENGTH 64
#define MAX_MAPNAME_LENGTH 64
#define ROUND_TIME_LENGTH 7
#define POSTFIX_LENGTH 8
#define MAX_CONFIG_FILENAME 32

enum _:XYZ { Float:X, Float:Y, Float:Z }
enum _:RGB { R, G, B }

enum _:MODE_DATA_STRUCT {
	PLAYER_COUNT,
	Float:ROUND_TIME,
	ROUND_TIME_STR[ROUND_TIME_LENGTH],
	CHAT_DESC[MAX_MODE_NAME_LENGTH],
	CHAT_COLOR,
	HUD_DESC[MAX_MODE_NAME_LENGTH],
	MAP_NAME[MAX_MAPNAME_LENGTH + POSTFIX_LENGTH],
	SPAWN_COUNT,
	ELEMENT_COUNT,
	NEXT_MODE
}

enum _:SPAWN_DATA_STRUCT {
	SPAWN_ID, // entity index
	TEAM_ID, // see 'TEAM_ENUM'
	Float:DEFAULT_ORIGIN[XYZ],
	Float:MODIFIED_ORIGIN[XYZ],
	Float:DEFAULT_ANGLE,
	Float:MODIFIED_ANGLE
}

enum _:ELEMENT_DATA_STUCT {
	ELEMENT_TYPE, // see 'ELEMENT_ENUM', can be ELEMENT_BLOCK <-> ELEMENT_BOMBSPOT
	ELEMENT_ID // this is entity index
}

enum _:ELEMENT_ENUM {
	ELEMENT_SPAWN,
	ELEMENT_BLOCK,
	ELEMENT_MODEL,
	ELEMENT_BUYZONE,
	ELEMENT_BOMBSPOT,
	ELEMENT_MODE
}

enum _:TEAM_ENUM {
	TEAMID_TT,
	TEAMID_CT
}

/* -------------------- */

enum _:RESULT_CODE_ENUM {
	RESULT_CODE__NOT_SET, // dummy state, used in conjunction with FORWARD_CALL__PRE
	RESULT_CODE__OK, // config loaded successfully
	RESULT_CODE__FAIL, // config was not found
	RESULT_CODE__ERROR // config was found, but reading fails
}

enum _:FORWARD_CALL_TYPE_NUM {
	FORWARD_CALL__PRE, // before procedure
	FORWARD_CALL__POST // after procedure
}

enum _:FORWARD_RETURN_TYPE { // NOTE: return in FORWARD_CALL__POST call doesn't affect anything
	FORWARD_RETURN__CONTINUE, // continue procedure
	FORWARD_RETURN__STOP // cancel procedure (post type will not be called)
}

/* -------------------- */

/**
 * Called when models config is loading.
 *
 * @param iCallType				Pre/Post call type, see 'FORWARD_CALL_TYPE_NUM'
 * @param iResultCode			Procedure result, see 'RESULT_CODE_ENUM'
 * @param iModelCount			Loaded models count
 * @param bMainCfgFound			Indicates that the main config was found (true) or not found (false)
 *
 * @return						FORWARD_RETURN__CONTINUE to continue loading config
 *								FORWARD_RETURN__STOP to block loading config
 */
forward MapBalance_OnModelCfgLoad(iCallType, iResultCode, iModelCount, bool:bMainCfgFound)

/**
 * Called when main config is loading.
 *
 * @param iCallType				Pre/Post call type, see 'FORWARD_CALL_TYPE_NUM'
 * @param iResultCode			Procedure result, see 'RESULT_CODE_ENUM'
 * @param bMainCfgFound			Indicates that the main config was found (true) or not found (false)
 *
 * @return						FORWARD_RETURN__CONTINUE to continue loading config
 *								FORWARD_RETURN__STOP to block loading config
 */
forward MapBalance_OnMainCfgLoad(iCallType, iResultCode, bool:bMainCfgFound)

/**
 * Called when system fully initializes.
 *
 * @note	If main сfg was loaded, but there is no modes defined, or if init mode is set to 'instant',
 *			this forward will be executed right after MapBalance_OnMainCfgLoad() post type.
 *
 * @param iCallType				Pre/Post call type, see 'FORWARD_CALL_TYPE_NUM'
 *
 * @return						FORWARD_RETURN__CONTINUE to continue initialization
 *								FORWARD_RETURN__STOP to prevent initialization
 */
forward MapBalance_OnSystemInit(iCallType)

/**
 * Called on new round, just before mode changing attempt.
 *
 * @note Will not be called if there is no modes defined, or if system is not initialized yet
 *
 * @param iCallType				Pre/Post call type, see 'FORWARD_CALL_TYPE_NUM'
 * @param iCurrentMode			Current mode index (0 means that this is default mode)
 * @param iRealPlCount			Real player count in game
 * @param iForcedPlCount		Current forced player count value (INVALID_HANDLE means
 *								that players count is not forced)
 *
 * @return						FORWARD_RETURN__CONTINUE to continue mode change attempt
 *								FORWARD_RETURN__STOP to prevent mode change attempt
 */
forward MapBalance_OnNewRoundEvent(iCallType, iCurrentMode, iRealPlCount, iForcedPlCount)

/**
 * Called after any mode was set.
 *
 * @param iNewMode				New mode index (0 means that this is default mode)
 *
 * @noreturn
 */
forward MapBalance_OnModeChange(iNewMode)

/**
 * Reloads main config and also rolls back all changes (disable current mode and remove all created entities).
 *
 * @note	Using this native will lead to MapBalance_OnMainCfgLoad() execution
 * @note	After using this native system will be automatically set to 'initialized' state, but without
 *			executing MapBalance_OnSystemInit() forward
 * @note	All current array handles will be unusable, and must be reobtained
 * @note	If used before OnConfigsExecuted(), further autoloading of main config will be skipped
 *
 * @noreturn
 */
native MapBalance_ReloadMainCfg()

/**
 * Returns system initialization status.
 */
native bool:MapBalance_GetInitState()

/**
 * Changes system initialization status.
 *
 * @note	Note that your actions can lead to MapBalance_OnSystemInit() forward execution.
 *
 * @param bInitState			System init state to set
 * @param bReaplyInitJob		When bInitState is false, will reaply automatic init procedure based
 *								on 'mb_init_mode' cvar value, as if this was config autoload
 *
 * @noreturn
*/
native MapBalance_SetInitState(bool:bInitState, bool:bReaplyInitJob)

/**
 * Returns models array handle (string array with MAX_MODEL_PATH_LENGTH size).
 *
 * @return						Array handle, or Invalid_Array if array not created yet.
 */
native Array:MapBalance_GetModelsArrayHandle()

/**
 * Returns model count.
 */
native MapBalance_GetModelCount()

/**
 * Returns mode data array handle (enumerated structure, see 'MODE_DATA_STRUCT').
 *
 * @note	Default mode will be on the first(0) position
 *
 * @return						Array handle, or Invalid_Array if array not created yet.
 */
native Array:MapBalance_GetMainArrayHandle()

/**
 * Returns mode count (default mode is not counted here).
 */
native MapBalance_GetModeCount()

/**
 * Returns spawn array handle for specified custom mode (enumerated structure, see 'SPAWN_DATA_STRUCT').
 *
 * @note	Mode enumeration starts from 1
 *
 * @param iModeID				Mode index, which array handle will be obtained
 *
 * @return						Array handle, or Invalid_Array if array is not created yet, or 
 *								if index is out of bounds.
 */
native Array:MapBalance_GetSpawnArrayHandle(iModeID)

/**
 * Returns element array handle for specified custom mode (enumerated structure, see 'ELEMENT_DATA_STUCT').
 *
 * @note	Mode enumeration starts from 1
 *
 * @param iModeID				Mode index, which array handle will be obtained
 *
 * @return						Array handle, or Invalid_Array if array is not created yet, or 
 *								if index is out of bounds.
 */
native Array:MapBalance_GetElementArrayHandle(iModeID)

/**
 * Changes current main config filepath.
 *
 * @param szCfgName				Config filename (without extention, should be .ini)
 *								in CFG_FOLDER_NAME (see main .sma)
 *
 * @return						True if config with new patch exists, false otherwise
 */
native bool:MapBalance_FormatMainCfgPath(szCfgName[MAX_CONFIG_FILENAME])

/**
 * Returns current mode index (0 means that this is default mode)
 */
native MapBalance_GetCurrentMode()

/**
 * Changes current mode 'on the fly'.
 *
 * @note	With successfull result, this will lead to MapBalance_OnModeChange() forward execution.
 *
 * @param iModeID				Mode index to set (pass 0 to set default mode)
 * @param bAnnouceInfo			If true, new mode information will be displayed to players
 *
 * @return						true if mode was set, false otherwise (if specified mode is alreay active,
 *								of if passed mode index is invalid)
 *
 */
native bool:MapBalance_SetCurrentMode(iModeID, bool:bAnnouceInfo)

/**
 * Returns current forced players count (INVALID_HANDLE means that players count is not forced)
 */
native MapBalance_GetForcedPlayersCount()

/**
 * Sets forced players count
 *
 * @note	Pass -1 to reset forcing
 *
 * @param iPlayerCount			Player count to force (-1 <-> 32)
 *
 * @noreturn
 */
native MapBalance_SetForcedPlayersCount(iPlayerCount)