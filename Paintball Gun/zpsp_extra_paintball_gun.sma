/*====================================================================================
		- [ZP] Extra Item: Paintball Gun
	
	- Description: 
	Hit Ink with Paintball Gun on top of zombies
	
	- Cvars:
	"zp_paintball_maxballs" - Max ink Entities
	"zp_paintball_lifetime" - Time For Remove ink Entities
	"zp_paintball_dmg_multi" - Damage Multi with Paintball Gun
	"zp_paintball_unlimited_clip" - Set's a Unlimited Clip With Paintball Gun
	
======================================================================================*/

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_plague_special>

#define ITEM_NAME "Paintball Gun"
#define ITEM_COST 50

#define PB_WPN_KEY 1664656581
new PAINTBALL_V_MODEL[64] = "models/zombie_plague/v_paintballgun.mdl"
new PAINTBALL_P_MODEL[64] = "models/zombie_plague/p_paintballgun.mdl"
new PAINTBALL_W_MODEL[64] = "models/zombie_plague/w_paintballgun.mdl"

new g_paintSprite[2][] = {"sprites/bhit.spr", "sprites/richo1.spr"}
new lastammo[33], g_paintball_gun[33], g_ballsnum = 0

// Cvars //
new paintball_lifetime, paintball_maxballs, paintball_dmg_multi, paintball_unlimited_clip, g_itemid

// CS Offsets
#if cellbits == 32
const OFFSET_CLIPAMMO = 51
#else
const OFFSET_CLIPAMMO = 65
#endif
const OFFSET_LINUX_WEAPONS = 4

// Max Clip for weapons
new const MAXCLIP[] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 }

public plugin_init() {
	register_plugin("[ZP] Extra Item: Paint Ball Gun", "1.1", "KRoTaL | [P]erfec[T] [S]cr[@]s[H]")
	register_cvar("zp_paintballgun", "1.1", FCVAR_SERVER|FCVAR_UNLOGGED);
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_mp5navy", "fw_AddToPlayer")
	register_forward(FM_SetModel, "fw_SetModel")
	register_event("CurWeapon", "make_paint", "be", "3>0")
	register_event("CurWeapon","checkModel","be","1=1")
	register_event("HLTV", "new_round", "a", "1=0", "2=0")
	register_message(get_user_msgid("CurWeapon"), "message_cur_weapon")
	
	paintball_maxballs = register_cvar("zp_paintball_maxballs", "200")
	paintball_lifetime = register_cvar("zp_paintball_lifetime", "10")
	paintball_dmg_multi = register_cvar("zp_paintball_dmg_multi", "4")
	paintball_unlimited_clip = register_cvar("zp_paintball_unlimited_clip", "1")
	
	g_itemid = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN)
}

public plugin_precache() {
	precache_model("sprites/bhit.spr")
	precache_model("sprites/richo1.spr")
	precache_model(PAINTBALL_V_MODEL)
	precache_model(PAINTBALL_P_MODEL)
	precache_model(PAINTBALL_W_MODEL)
}
/*----------------------------------------=[Unlimited Clip]=------------------------------------------*/
// Unlimited clip code
public message_cur_weapon(msg_id, msg_dest, msg_entity) {
	if (!is_user_alive(msg_entity) || !get_pcvar_num(paintball_unlimited_clip))
		return;

	// Player doesn't have the unlimited clip upgrade
	if (!g_paintball_gun[msg_entity]  || get_msg_arg_int(1) != 1)
		return;
	
	static weapon, clip
	weapon = get_msg_arg_int(2) // get weapon ID
	clip = get_msg_arg_int(3) // get weapon clip

	if(weapon != CSW_ELITE)
		return;
	
	// Unlimited Clip Ammo
	if (MAXCLIP[weapon] > 2) // skip grenades
	{
		set_msg_arg_int(3, get_msg_argtype(3), MAXCLIP[weapon]) // HUD should show full clip all the time
		
		if (clip < 2) // refill when clip is nearly empty
		{
			// Get the weapon entity
			static wname[32], weapon_ent
			get_weaponname(weapon, wname, sizeof wname - 1)
			weapon_ent = find_ent_by_owner(-1, wname, msg_entity)
			
			// Set max clip on weapon
			set_pdata_int(weapon_ent, OFFSET_CLIPAMMO, MAXCLIP[weapon], OFFSET_LINUX_WEAPONS)
		}
	}
}



public fw_TakeDamage(victim, inflictor, attacker, Float:damage) {
	if(!is_user_alive(attacker))
		return HAM_IGNORED

	if(!g_paintball_gun[attacker] || zp_get_user_zombie(attacker))
		return HAM_IGNORED

	if (get_user_weapon(attacker) == CSW_MP5NAVY) {
		SetHamParamFloat(4, damage * get_pcvar_float(paintball_dmg_multi))
		
		zp_set_user_rendering(victim, kRenderFxGlowShell, random_num(0,255), random_num(0,255), random_num(0,255), kRenderNormal, 16);
		set_task(5.0, "remove_glow", victim)
	}
	return HAM_IGNORED
}

public zp_extra_item_selected_pre(id, itemid) {
	if (itemid == g_itemid && g_paintball_gun[id])
		return ZP_PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public zp_extra_item_selected(id, itemid) {
	if (itemid != g_itemid)
		return PLUGIN_CONTINUE;
	
	if(g_paintball_gun[id]) {
		client_print_color(id, print_team_default, "^4[ZP]^3 You Have Alterady the ^1Paintball Gun")
		return ZP_PLUGIN_HANDLED;
	}
	
	g_paintball_gun[id] = true
	zp_give_item(id, "weapon_mp5navy")
	client_print_color(id, print_team_default, "^4[ZP]^3 You Have Bought a ^1Paintball Gun")
	
	return PLUGIN_CONTINUE;
}

public remove_glow(id) {
	zp_reset_user_rendering(id);
}

public checkModel(id) {
	if (zp_get_user_zombie(id)) return PLUGIN_HANDLED;
	
	new szWeapID = read_data(2)
	
	if ( szWeapID == CSW_MP5NAVY && g_paintball_gun[id]) {
		set_pev(id, pev_viewmodel2, PAINTBALL_V_MODEL)
		set_pev(id, pev_weaponmodel2, PAINTBALL_P_MODEL)
	}
	return PLUGIN_HANDLED
}

public make_paint(id) {
	if(!is_user_alive(id))
		return;

	if(!g_paintball_gun[id] || zp_get_user_zombie(id))
		return;

	static ammo;
	ammo = read_data(3)
	
	if(get_user_weapon(id) == CSW_MP5NAVY  && lastammo[id] > ammo) {
		static iOrigin[3],  Float:fOrigin[3]
		get_user_origin(id, iOrigin, 4)
		IVecFVec(iOrigin, fOrigin)
		
		if(g_ballsnum < get_pcvar_num(paintball_maxballs) && worldInVicinity(fOrigin)) {
			new ent = create_entity("info_target")
			if(ent > 0) {
				entity_set_string(ent, EV_SZ_classname, "paint_ent")
				entity_set_int(ent, EV_INT_movetype, 0)
				entity_set_int(ent, EV_INT_solid, 0)
				entity_set_model(ent, g_paintSprite[random_num(0,1)])
				
				static r, g, b
				r = random_num(64, 255)
				g = random_num(64, 255)
				b = random_num(64, 255)
				
				set_rendering(ent, kRenderFxNoDissipation, r, g, b, kRenderGlow, 255)
				entity_set_origin(ent, fOrigin)
				entity_set_int(ent, EV_INT_flags, FL_ALWAYSTHINK)
				entity_set_float(ent, EV_FL_nextthink, get_gametime() + get_pcvar_float(paintball_lifetime))
				++g_ballsnum
			}
		}
	}
	lastammo[id] = ammo
}

public pfn_think(entity) 
{
	if(!is_valid_ent(entity))
		return
	
	static class[32]; entity_get_string(entity, EV_SZ_classname, class, charsmax(class))
	if(entity > 0 && equal(class, "paint_ent")) 
	{
		remove_entity(entity)
		--g_ballsnum
	}
}

public new_round() {
	static id
	for(id = 1; id <= MaxClients; id++) 
		g_paintball_gun[id] = false
	
	remove_entity_name("paint_ent")
	g_ballsnum = 0
}

stock worldInVicinity(Float:origin[3]) 
{
	new ent = find_ent_in_sphere(-1, origin, 4.0)
	while(ent > 0) {
		if(entity_get_float(ent, EV_FL_health) > 0 || entity_get_float(ent, EV_FL_takedamage) > 0.0) return 0;
		ent = find_ent_in_sphere(ent, origin, 4.0)
	}
	
	new Float:traceEnds[8][3], Float:traceHit[3], hitEnt
	
	traceEnds[0][0] = origin[0] - 2.0; traceEnds[0][1] = origin[1] - 2.0; traceEnds[0][2] = origin[2] - 2.0
	traceEnds[1][0] = origin[0] - 2.0; traceEnds[1][1] = origin[1] - 2.0; traceEnds[1][2] = origin[2] + 2.0
	traceEnds[2][0] = origin[0] + 2.0; traceEnds[2][1] = origin[1] - 2.0; traceEnds[2][2] = origin[2] + 2.0
	traceEnds[3][0] = origin[0] + 2.0; traceEnds[3][1] = origin[1] - 2.0; traceEnds[3][2] = origin[2] - 2.0
	traceEnds[4][0] = origin[0] - 2.0; traceEnds[4][1] = origin[1] + 2.0; traceEnds[4][2] = origin[2] - 2.0
	traceEnds[5][0] = origin[0] - 2.0; traceEnds[5][1] = origin[1] + 2.0; traceEnds[5][2] = origin[2] + 2.0
	traceEnds[6][0] = origin[0] + 2.0; traceEnds[6][1] = origin[1] + 2.0; traceEnds[6][2] = origin[2] + 2.0
	traceEnds[7][0] = origin[0] + 2.0; traceEnds[7][1] = origin[1] + 2.0; traceEnds[7][2] = origin[2] - 2.0
	
	for (new i = 0; i < 8; i++) 
	{
		if (PointContents(traceEnds[i]) != CONTENTS_EMPTY) return 1;
	
		hitEnt = trace_line(0, origin, traceEnds[i], traceHit)
		if (hitEnt != -1) return 1;
		
		for (new j = 0; j < 3; j++) if (traceEnds[i][j] != traceHit[j]) return 1;
	}
	return 0
}

public fw_SetModel(entity, model[]) {
	if(!is_valid_ent(entity))
		return FMRES_IGNORED;

	if(!equal(model, "models/w_mp5.mdl")) 
		return FMRES_IGNORED;

	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
	if(!equal(szClassName, "weaponbox")) return FMRES_IGNORED

	static iOwner, iStoredMp5ID
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	iStoredMp5ID = find_ent_by_owner(-1, "weapon_mp5navy", entity)

	if(g_paintball_gun[iOwner] && is_valid_ent(iStoredMp5ID)) {
		g_paintball_gun[iOwner] = false
		entity_set_int(iStoredMp5ID, EV_INT_impulse, PB_WPN_KEY)
		entity_set_model(entity, PAINTBALL_W_MODEL)

		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(wpn, id) {
	if(is_valid_ent(wpn) && is_user_connected(id) && entity_get_int(wpn, EV_INT_impulse) == PB_WPN_KEY) {
		g_paintball_gun[id] = true
		entity_set_int(wpn, EV_INT_impulse, 0)

		return HAM_HANDLED
	}
	return HAM_IGNORED
}