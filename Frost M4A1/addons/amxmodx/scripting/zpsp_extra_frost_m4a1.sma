/*==============================================================================
				[ZPSp] Extra Item: Frost M4A1

	-> Description:
		Can frost zombies with this weapon

	-> Requeriments:
		Zombie Plague Special 4.5

	-> Credits:
		- Raheem: Original version
		- ShaunCraft15: Custom trail
		- Perfect Scrash: Otimization and for ZPSp 4.5 version
===============================================================================*/

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <zombie_plague_special>

// Check include version
#if ZPS_INC_VERSION < 45
	#assert Zombie Plague Special 4.5 Include File Required. Download Link: https://forums.alliedmods.net/showthread.php?t=260845
#endif

/*============================================
-> Plugin Configuration
============================================*/
// Extra item configs
new const ITEM_NAME[] = "Frost M4A1";
new const ITEM_COST = 100;

// Weapon Model
new const V_WPN_MODEL[] = "models/zombie_plague/v_frost_m4a1.mdl";
new const P_WPN_MODEL[] = "models/zombie_plague/p_frost_m4a1.mdl";
new const W_WPN_MODEL[] = "models/zombie_plague/w_frost_m4a1.mdl";
new const W_OLD_WPN_MODEL[] = "models/w_m4a1.mdl";

// Weapon Type (Can change to other weapon easily)
new const WPN_ENTITY[] = "weapon_m4a1"
const WPN_CSW = CSW_M4A1;
const WPN_TYPE = WPN_PRIMARY;
const WPN_KEY = 1997;

// Sprite effects
enum _:Sprites { SPR_FROST, SPR_FROST2, SPR_FLAKE, SPR_TRACE, SPR_RING, MAX_SPRITES }
new const FrostSprites[MAX_SPRITES][] = { 
	"sprites/frostexp_1.spr",
	"sprites/frostexp_2.spr",
	"sprites/snowflake_1.spr",
	"sprites/Newlightning.spr",
	"sprites/shockwave.spr"
}

/*============================================
-> Variables/Consts
============================================*/
new const TracePreEntities[][] = { "func_breakable", "func_wall", "func_door", "func_door_rotating", "func_plat", "func_rotating", "player", "worldspawn" }
new g_iItemID, g_iHudSync, m_FrostSpr[MAX_SPRITES], cvar_dmg_frost, cvar_frost_time, cvar_dmg_multi, bool:g_haveFrostWeapon[33], g_iDmg[33];

/*============================================
-> Plugin Registeration
============================================*/
public plugin_init() {
	// Plugin Registeration
	register_plugin("[ZPSp] Extra Item: Frost M4A1", "1.0", "Raheem | Perf. Scrash")
	
	// Cvars
	cvar_frost_time = register_cvar("zp_frost_m4a1_time", "2.0") // Freeze Time. It's Float you can make it 0.5
	cvar_dmg_frost = register_cvar("zp_freezing_m4a1_damage", "1000") // Damage Requried So Zombie got Frozen
	cvar_dmg_multi = register_cvar("zp_multiplier_m4a1_damage", "2") // Multiplie Weapon Damage

	// Forwards
	register_forward(FM_SetModel, "fw_SetModel")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_AddToPlayer, WPN_ENTITY, "fw_WpnAddToPlayer")

	for(new i = 0; i < sizeof TracePreEntities; i++)
		RegisterHam(Ham_TraceAttack, TracePreEntities[i], "fw_TraceAttackPre");
	
	g_iItemID = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN) // Item Registeration
	g_iHudSync = CreateHudSyncObj() // Message IDS
}

/*============================================
-> Plugin Precache
============================================*/
public plugin_precache() {
	// Models
	precache_model(V_WPN_MODEL)
	precache_model(P_WPN_MODEL)
	precache_model(W_WPN_MODEL)
	
	// Sprites
	for(new i = 0; i < MAX_SPRITES; i++)
		m_FrostSpr[i] = precache_model(FrostSprites[i]);
}

/*============================================
-> Reset Variables
============================================*/
public client_disconnected(id) reset_vars(id);
public zp_user_infected_post(id) reset_vars(id);
public zp_user_humanized_post(id) reset_vars(id);
public zp_player_spawn_post(id) reset_vars(id);
public reset_vars(id) {
	g_haveFrostWeapon[id] = false
	g_iDmg[id] = 0
}

/*============================================
-> Extra Item functions
============================================*/
public zp_extra_item_selected_pre(player, itemid) {
	if(itemid != g_iItemID) 
		return PLUGIN_CONTINUE;

	if(g_haveFrostWeapon[player]) {
		zp_menu_textadd("\r[Alterady Have]")
		return ZP_PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;	
}
public zp_extra_item_selected(player, itemid) {
	if(itemid != g_iItemID) 
		return PLUGIN_CONTINUE;

	if(g_haveFrostWeapon[player])
		return ZP_PLUGIN_HANDLED;

	g_haveFrostWeapon[player] = true
	zp_drop_weapons(player, WPN_TYPE);
	zp_give_item(player, WPN_ENTITY, 1)
	client_print_color(player, print_team_grey, "^4[ZP]^3 You bought ^1%s^3 With Sucess !!!", ITEM_NAME)

	return PLUGIN_CONTINUE;
}

/*============================================
-> Trace and Damage Functions
============================================*/
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type) {
	if(!is_user_alive(victim) || !is_user_alive(attacker))
		return HAM_IGNORED

	if(!g_haveFrostWeapon[attacker])
		return HAM_IGNORED;

	if(zp_get_zombie_special_class(victim) || !zp_get_user_zombie(victim) || get_user_weapon(attacker) != WPN_CSW)
		return HAM_IGNORED

	static CvarDmgFrost; CvarDmgFrost = get_pcvar_num(cvar_dmg_frost);

	damage *= get_pcvar_float(cvar_dmg_multi)
	g_iDmg[attacker] += floatround(damage);
	SetHamParamFloat(4, damage);

	set_hudmessage(0, 50, 200, -1.0, 0.17, 0, 6.0, 0.3, 0.1, 0.2)
	ShowSyncHudMsg(attacker, g_iHudSync, "Damage to frost: %d/%d", g_iDmg[attacker], CvarDmgFrost)

	if(g_iDmg[attacker] >= CvarDmgFrost) {
		SetPlayerFrostEffects(victim) // Give a frost effects
		g_iDmg[attacker] = 0
	}
	return HAM_IGNORED
}

public fw_TraceAttackPre(iVictim, iAttacker, Float:fDamage, Float:fDeriction[3], iTraceHandle, iBitDamage) {
	if(!is_user_alive(iAttacker))
		return;

	if(get_user_weapon(iAttacker) != WPN_CSW || !g_haveFrostWeapon[iAttacker]) 
		return;

	free_tr2(iTraceHandle);

	static Float:end[3]
	get_tr2(iTraceHandle, TR_vecEndPos, end)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(iAttacker | 0x1000)
	engfunc(EngFunc_WriteCoord, end[0])
	engfunc(EngFunc_WriteCoord, end[1])
	engfunc(EngFunc_WriteCoord, end[2])
	write_short(m_FrostSpr[SPR_TRACE])
	write_byte(1) // framerate
	write_byte(5) // framerate
	write_byte(1) // life
	write_byte(20)  // width
	write_byte(0)// noise
	write_byte(0)// r, g, b
	write_byte(100)// r, g, b
	write_byte(255)// r, g, b
	write_byte(220)	// brightness
	write_byte(150)	// speed
	message_end()
}

/*============================================
-> Weapon Model 
============================================*/
// P_ and V_ model
public zp_fw_deploy_weapon(id, wpn_id) {
	if(!is_user_alive(id) || wpn_id != WPN_CSW)
		return;

	if(g_haveFrostWeapon[id]) {
		set_pev(id, pev_viewmodel2, V_WPN_MODEL)
		set_pev(id, pev_weaponmodel2, P_WPN_MODEL)
	}
}

// W_ Model (On drop)
public fw_SetModel(entity, model[]) {
	if(!pev_valid(entity)) 
		return FMRES_IGNORED

	if(!equali(model, W_OLD_WPN_MODEL)) 
		return FMRES_IGNORED

	static className[32], iOwner, iStoredWeapon;
	pev(entity, pev_classname, className, charsmax(className))

	iOwner = pev(entity, pev_owner) // Frost M4A1 Owner
	iStoredWeapon = fm_find_ent_by_owner(-1, WPN_ENTITY, entity) // Get drop weapon index (Frost M4A1) to use in fw_WpnAddToPlayer forward

	// If Player Has Frost M4A1 and It's weapon_m4a1
	if(g_haveFrostWeapon[iOwner] && pev_valid(iStoredWeapon)) {
		set_pev(iStoredWeapon, pev_impulse, WPN_KEY) // Setting weapon options
		g_haveFrostWeapon[iOwner] = false // Rest Var
		engfunc(EngFunc_SetModel, entity, W_WPN_MODEL) // Set weaponbox new model
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

// W_ Model (On Pickup)
public fw_WpnAddToPlayer(wpn_ent, id) {
	// Make sure that this is M4A1
	if(pev_valid(wpn_ent) && is_user_connected(id) && pev(wpn_ent, pev_impulse) == WPN_KEY) {
		g_haveFrostWeapon[id] = true // Update Var
		set_pev(wpn_ent, pev_impulse, 0) // Reset weapon options
		return HAM_HANDLED;
	}
	return HAM_IGNORED
}

/*============================================
-> Functions/Stocks 
============================================*/
// Frost Player Effects
SetPlayerFrostEffects(id) {
	if(!is_user_alive(id))
		return;

	// Set player Frost
	zp_set_user_frozen(id, SET, get_pcvar_float(cvar_frost_time));

	// For Frost Effect Ring
	static Float:originF3[3];
	pev(id, pev_origin, originF3)

	UTIL_Explosion(originF3, m_FrostSpr[SPR_FROST], 40, 30, 4)
	UTIL_Explosion(originF3, m_FrostSpr[SPR_FROST2], 20, 30, 4)
	UTIL_SpriteTrail(originF3, m_FrostSpr[SPR_FLAKE], 30, 3, 2, 30, 0)

	// Ring effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF3, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF3[0]) // x
	engfunc(EngFunc_WriteCoord, originF3[1]) // y
	engfunc(EngFunc_WriteCoord, originF3[2]) // z
	engfunc(EngFunc_WriteCoord, originF3[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF3[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF3[2]+100.0) // z axis
	write_short(m_FrostSpr[SPR_RING]) // sprite
	write_byte(0) // startframe
	write_byte(1) // framerate
	write_byte(3) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(41) // red
	write_byte(138) // green
	write_byte(255) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

UTIL_Explosion(Float:vOrigin[3], iSprite, iScale, iFramerate, Flags) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vOrigin[0])
	engfunc(EngFunc_WriteCoord, vOrigin[1])
	engfunc(EngFunc_WriteCoord, vOrigin[2])
	write_short(iSprite)
	write_byte(iScale)
	write_byte(iFramerate)
	write_byte(Flags)
	message_end()
}

UTIL_SpriteTrail(Float:vOrigin[3], iSprite, iCount, iLife, iScale, iVelocity, iVary) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPRITETRAIL)
	engfunc(EngFunc_WriteCoord, vOrigin[0])
	engfunc(EngFunc_WriteCoord, vOrigin[1])
	engfunc(EngFunc_WriteCoord, vOrigin[2] + 100)
	engfunc(EngFunc_WriteCoord, vOrigin[0] + random_float( -200.0, 200.0 ))
	engfunc(EngFunc_WriteCoord, vOrigin[1] + random_float( -200.0, 200.0 ))
	engfunc(EngFunc_WriteCoord, vOrigin[2])
	write_short(iSprite)
	write_byte(iCount)
	write_byte(iLife)
	write_byte(iScale)
	write_byte(iVelocity)
	write_byte(iVary)
	message_end()
}

// From fakemeta_util
stock fm_find_ent_by_owner(index, const classname[], owner, jghgtype = 0) {
	new strtype[11] = "classname", ent = index;
	switch (jghgtype) {
		case 1: strtype = "target";
		case 2: strtype = "targetname";
	}

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, strtype, classname)) && pev(ent, pev_owner) != owner) {}

	return ent;
}
