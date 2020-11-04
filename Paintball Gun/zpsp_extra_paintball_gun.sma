/*====================================================================================
		- [ZP] Extra Item: Paintball Gun
	
	- Description: 
	Hit Ink with Paintball Gun on top of zombies
	
	- Cvar´s:
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

new PAINTBALL_V_MODEL[64] = "models/zombie_plague/v_paintballgun.mdl"
new PAINTBALL_P_MODEL[64] = "models/zombie_plague/p_paintballgun.mdl"
new PAINTBALL_W_MODEL[64] = "models/zombie_plague/w_paintballgun.mdl"

new g_paintSprite[2][] = {"sprites/bhit.spr", "sprites/richo1.spr"}
new lastammo[33], g_paintball_gun[33], g_ballsnum = 0

// Cvars //
new paintball_lifetime, paintball_maxballs, paintball_dmg_multi, paintball_unlimited_clip, g_itemid

public plugin_init()
{
	register_plugin("[ZP] Extra Item: Paint Ball Gun", "1.1", "KRoTaL | [P]erfec[T] [S]cr[@]s[H]")
	register_cvar("zp_paintballgun", "1.1", FCVAR_SERVER|FCVAR_UNLOGGED);
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_mp5navy", "fw_AddToPlayer")
	register_forward(FM_SetModel, "fw_SetModel")
	register_event("CurWeapon", "make_paint", "be", "3>0")
	register_event("WeapPickup","checkModel","b","1=19")
	register_event("CurWeapon","checkWeapon","be","1=1")
	register_event("HLTV", "new_round", "a", "1=0", "2=0")
	
	paintball_maxballs = register_cvar("zp_paintball_maxballs", "200")
	paintball_lifetime = register_cvar("zp_paintball_lifetime", "10")
	paintball_dmg_multi = register_cvar("zp_paintball_dmg_multi", "4")
	paintball_unlimited_clip = register_cvar("zp_paintball_unlimited_clip", "1")
	
	g_itemid = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN)
}

public plugin_precache()
{
	precache_model("sprites/bhit.spr")
	precache_model("sprites/richo1.spr")
	precache_model(PAINTBALL_V_MODEL)
	precache_model(PAINTBALL_P_MODEL)
	precache_model(PAINTBALL_W_MODEL)
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (is_user_alive(attacker) && get_user_weapon(attacker) == CSW_MP5NAVY && g_paintball_gun[attacker] && !zp_get_user_zombie(attacker))
	{
		SetHamParamFloat(4, damage * get_pcvar_float(paintball_dmg_multi))
		
		zp_set_user_rendering(victim, kRenderFxGlowShell, random_num(0,255), random_num(0,255), random_num(0,255), kRenderNormal, 16);
		set_task(5.0, "remove_glow", victim)
	}
}

public zp_extra_item_selected_pre(id, itemid)
{
	if (itemid == g_itemid && g_paintball_gun[id])
		return ZP_PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public zp_extra_item_selected(id, itemid)
{
	if (itemid == g_itemid)
	{
		if(g_paintball_gun[id])
		{
			client_printcolor(id, "!g[ZP]!t You Have Alterady the !gPaintball Gun")
			return ZP_PLUGIN_HANDLED;
		}
		
		g_paintball_gun[id] = true
		give_item(id, "weapon_mp5navy")
		client_printcolor(id, "!g[ZP]!t You Have Bought a !gPaintball Gun")
	}
	
	return PLUGIN_CONTINUE;
}

public remove_glow(id) {
	zp_reset_user_rendering(id);
}

public checkWeapon(id)
{
	new plrClip, plrAmmo, plrWeap[32], plrWeapId
	
	plrWeapId = get_user_weapon(id, plrClip , plrAmmo)
	
	if (plrWeapId == CSW_MP5NAVY && g_paintball_gun[id])
		checkModel(id)

	else return PLUGIN_CONTINUE;
	
	if (plrClip == 0 && get_pcvar_num(paintball_unlimited_clip))
	{
		// If the user is out of ammo..
		get_weaponname(plrWeapId, plrWeap, 31)
		// Get the name of their weapon
		give_item(id, plrWeap)
		engclient_cmd(id, plrWeap) 
		engclient_cmd(id, plrWeap)
		engclient_cmd(id, plrWeap)
	}
	return PLUGIN_HANDLED
}

public checkModel(id)
{
	if (zp_get_user_zombie(id)) return PLUGIN_HANDLED;
	
	new szWeapID = read_data(2)
	
	if ( szWeapID == CSW_MP5NAVY && g_paintball_gun[id])
	{
		entity_set_string(id, EV_SZ_viewmodel, PAINTBALL_V_MODEL)
		entity_set_string(id, EV_SZ_weaponmodel, PAINTBALL_P_MODEL)
	}
	return PLUGIN_HANDLED
}

public make_paint(id)
{
	new ammo = read_data(3)
	
	if(get_user_weapon(id) == CSW_MP5NAVY  && lastammo[id] > ammo && g_paintball_gun[id])
	{
		new iOrigin[3]
		get_user_origin(id, iOrigin, 4)
		new Float:fOrigin[3]
		IVecFVec(iOrigin, fOrigin)
		
		if(g_ballsnum < get_pcvar_num(paintball_maxballs) && worldInVicinity(fOrigin))
		{
			new ent = create_entity("info_target")
			if(ent > 0)
			{
				entity_set_string(ent, EV_SZ_classname, "paint_ent")
				entity_set_int(ent, EV_INT_movetype, 0)
				entity_set_int(ent, EV_INT_solid, 0)
				entity_set_model(ent, g_paintSprite[random_num(0,1)])
				new r, g, b

				r = random_num(64,255)
				g = random_num(64,255)
				b = random_num(64,255)
				
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
	
	new class[32]; entity_get_string(entity, EV_SZ_classname, class, 31)
	if(entity > 0 && equal(class, "paint_ent")) 
	{
		remove_entity(entity)
		--g_ballsnum
	}
}

public new_round()
{
	for(new id = 1; id <= get_maxplayers(); id++) g_paintball_gun[id] = false
	
	remove_entity_name("paint_ent")
	g_ballsnum = 0
}

stock worldInVicinity(Float:origin[3]) 
{
	new ent = find_ent_in_sphere(-1, origin, 4.0)
	while(ent > 0)
	{
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

public fw_SetModel(entity, model[])
{
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

	if(g_paintball_gun[iOwner] && is_valid_ent(iStoredMp5ID))
	{
		g_paintball_gun[iOwner] = false
		entity_set_int(iStoredMp5ID, EV_INT_impulse, 1664656581)
		entity_set_model(entity, PAINTBALL_W_MODEL)

		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(wpn, id)
{
	if(is_valid_ent(wpn) && is_user_connected(id) && entity_get_int(wpn, EV_INT_impulse) == 1664656581)
	{
		g_paintball_gun[id] = true
		entity_set_int(wpn, EV_INT_impulse, 0)

		return HAM_HANDLED
	}
	return HAM_IGNORED
}

stock give_item(index, const item[]) {
	if (!equal(item, "weapon_", 7) && !equal(item, "ammo_", 5) && !equal(item, "item_", 5) && !equal(item, "tf_weapon_", 10))
		return 0;

	new ent = create_entity(item);
	if (!pev_valid(ent))
		return 0;

	new Float:origin[3];
	pev(index, pev_origin, origin);
	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_spawnflags, pev(ent, pev_spawnflags) | SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn, ent);

	new save = pev(ent, pev_solid);
	dllfunc(DLLFunc_Touch, ent, index);
	if (pev(ent, pev_solid) != save)
		return ent;

	engfunc(EngFunc_RemoveEntity, ent);

	return -1;
}

stock client_printcolor(const id,const input[], any:...)
{
	new msg[191], players[32], count = 1
	vformat(msg,190,input,3);
	replace_all(msg,190,"!g","^4");    // green
	replace_all(msg,190,"!y","^1");    // normal
	replace_all(msg,190,"!t","^3");    // team
	    
	if (id) players[0] = id; else get_players(players,count,"ch");
	    
	for (new i=0;i<count;i++)
	{
		if (is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("SayText"),_,players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
	}
} 
