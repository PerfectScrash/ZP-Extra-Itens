/*-----------------------------------------------------------------------------------------------------
				[Elemental Fire & Ice | Credits:]
				
		* [P]erfec[T] [S]cr[@]s[H]: For ZP 4.3, ZPA, ZP Shade, ZP Special Version
		* metallicawOw: Thanks for the Nitrogen Galil's Code
		* Javivi: Thanks for the Flame XM1014's Code
		* Catastrophe: For ZP 5.0 Version
		* Nightmare: For Elemental Weapon Model
		* Sergio #: For Fixed Some Bugs
------------------------------------------------------------------------------------------------------*/

/*-------------------------------------------=[Includes]=---------------------------------------------*/
#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <xs>
#include <hamsandwich>
#include <zombie_plague_special>

/*-------------------------------=[Variables, Conts, Defines & Cvars]=--------------------------------*/

new EL_V_MODEL[64] = "models/zombie_plague/v_Elemental.mdl"
new EL_P_MODEL[64] = "models/zombie_plague/p_Elemental.mdl"
new EL_W_MODEL[64] = "models/zombie_plague/w_Elemental.mdl"
new EL_OLD_W_MODEL[64] = "models/w_elite.mdl"

new cvar_custommodel, cvar_tracer, cvar_uclip, cvar_fr_duration, cvar_f_duration, cvar_oneround, cvar_dmgmultiplier, cvar_limit
new g_itemid, g_elemental[33], g_zoom[33], righthand[33], tracer_spr, g_buy_limit, g_maxplayers

const SECONDARY_BIT_SUM = (1<<CSW_USP)|(1<<CSW_DEAGLE)|(1<<CSW_GLOCK18)|(1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)

#define ITEM_NAME "Elemental \r[Fire & Ice]"
#define ITEM_COST 40

// CS Offsets
#if cellbits == 32
const OFFSET_CLIPAMMO = 51
#else
const OFFSET_CLIPAMMO = 65
#endif
const OFFSET_LINUX_WEAPONS = 4

#define is_user_valid_alive(%1) (1 <= %1 <= g_maxplayers && is_user_alive(%1))

// Max Clip for weapons
new const MAXCLIP[] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 }

// Trace attack entities
new const TracePreEntities[][] = { "func_breakable", "func_wall", "func_door", "func_door_rotating", "func_plat", "func_rotating", "player", "worldspawn" }
/*---------------------------------------=[Plugin Register]=-----------------------------------------*/
public plugin_init()
{	
	// Register The Plugin
	register_plugin("[ZP] Extra: Elemental", "1.3", "Catastrophe | [P]erfec[T] [S]cr[@]s[H]")
	register_cvar("zp_elemental", "1.3", FCVAR_SERVER|FCVAR_SPONLY)
	
	// Register Zombie Plague extra item
	g_itemid = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN)
	
	// Death Msg
	register_event("DeathMsg", "Death", "a")
	register_event("CurWeapon","event_CurWeapon","be","1=1")
	register_message(get_user_msgid("CurWeapon"), "message_cur_weapon")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	
	// Forwards
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Ham TakeDamage
	RegisterHam(Ham_Item_AddToPlayer, "weapon_elite", "fw_AddToPlayer")
	for(new i = 0; i < sizeof TracePreEntities; i++)
		RegisterHam(Ham_TraceAttack, TracePreEntities[i], "fw_TraceAttackPre");
	
	// Cvars
	cvar_dmgmultiplier = register_cvar("zp_elemental_dmg_multiplier", "3")   // Elemental Damage Multipler
	cvar_custommodel = register_cvar("zp_elemental_custom_model", "1")	// Custom Model (0 - Off | 1 - On)
	cvar_uclip = register_cvar("zp_elemental_unlimited_clip", "1")		// Unlimited Clip (0 - Off | 1 - On)
	cvar_fr_duration = register_cvar("zp_elemental_frost_time", "5.0")	// Time will be frozen
	cvar_f_duration = register_cvar("zp_elemental_fire_time", "12")		// Time will be burning
	cvar_tracer = register_cvar("zp_elemental_tracers", "1")			// Tracer? (0 - Off | 1 - On)
	cvar_oneround = register_cvar("zp_elemental_one_round", "1")		// The Elemental should be 1 round? (1 - On | 0 - Off)
	cvar_limit = register_cvar("zp_elemental_buy_limit", "3")		// Buy Limit Per Round
	
	g_maxplayers = get_maxplayers()
}

/*------------------------------------------=[Precaches]=--------------------------------------------*/
public plugin_precache()
{
	precache_model(EL_V_MODEL)
	precache_model(EL_P_MODEL)
	precache_model(EL_W_MODEL)
	precache_model(EL_OLD_W_MODEL)
	
	tracer_spr = precache_model("sprites/dot.spr")
	precache_sound("weapons/zoom.wav")
}

/*---------------------------------------=[Bug Prevention]=-----------------------------------------*/
public client_putinserver(id) g_elemental[id] = false;
public Death() g_elemental[read_data(2)] = false;
public zp_user_infected_post(id) g_elemental[id] = false;
public zp_user_humanized_post(id) g_elemental[id] = false;

public event_round_start() 
{
	g_buy_limit = 0
	
	if(get_pcvar_num(cvar_oneround))
	{
		for(new id = 1; id <= g_maxplayers; id++) 
			g_elemental[id] = false
	}		
}

/*----------------------------------------=[Custom Model]=-------------------------------------------*/
public event_CurWeapon(id)
{
	if (!is_user_valid_alive(id) || zp_get_user_zombie(id)) return PLUGIN_HANDLED
	
	new g_Weapon = read_data(2)
	if (g_Weapon == CSW_ELITE && g_elemental[id] && get_pcvar_num(cvar_custommodel))
	{
		set_pev(id, pev_viewmodel2, EL_V_MODEL)
		set_pev(id, pev_weaponmodel2, EL_P_MODEL)
	}
	return PLUGIN_CONTINUE
}

/*----------------------------------------=[Unlimited Clip]=------------------------------------------*/
// Unlimited clip code
public message_cur_weapon(msg_id, msg_dest, msg_entity)
{
	if (!is_user_alive(msg_entity) || !get_pcvar_num(cvar_uclip))
		return;

	// Player doesn't have the unlimited clip upgrade
	if (!g_elemental[msg_entity]  || get_msg_arg_int(1) != 1)
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

/*-----------------------------------------=[World Model]=-------------------------------------------*/
public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity) || !equal(model, EL_OLD_W_MODEL)) return FMRES_IGNORED;
	
	static szClassName[33]; pev(entity, pev_classname, szClassName, charsmax(szClassName))
	if(!equal(szClassName, "weaponbox")) return FMRES_IGNORED;
	
	static owner, wpn
	owner = pev(entity, pev_owner)
	wpn = find_ent_by_owner(-1, "weapon_elite", entity)
	
	if(g_elemental[owner] && pev_valid(wpn))
	{
		g_elemental[owner] = false
		set_pev(wpn, pev_impulse, 324584)
		engfunc(EngFunc_SetModel, entity, EL_W_MODEL)
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(wpn, id)
{
	if(pev_valid(wpn) && is_user_connected(id) && pev(wpn, pev_impulse) == 324584)
	{
		g_elemental[id] = true
		set_pev(wpn, pev_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}


/*-----------------------------------------=[Weapon Zoom]=-------------------------------------------*/
public fw_CmdStart(id, uc_handle, seed)
{
	new szClip, szAmmo, szWeapID = get_user_weapon(id, szClip, szAmmo)

	if(!is_user_valid_alive(id) || zp_get_user_zombie(id) || szWeapID != CSW_ELITE && g_zoom[id]) 
	{
		g_zoom[id] = false
		cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
		return PLUGIN_HANDLED;
	}

	if((get_uc(uc_handle, UC_Buttons) & IN_ATTACK2) && !(pev(id, pev_oldbuttons) & IN_ATTACK2))
	{		
		if(szWeapID == CSW_ELITE && g_elemental[id] && !g_zoom[id])
		{
			g_zoom[id] = true
			cs_set_user_zoom(id, CS_SET_AUGSG552_ZOOM, 0)
			emit_sound(id, CHAN_ITEM, "weapons/zoom.wav", 0.20, 2.40, 0, 100)
		}
		else if (szWeapID == CSW_ELITE && g_elemental[id] && g_zoom[id])
		{
			g_zoom[id] = false
			cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
		}
	}	
	return PLUGIN_HANDLED
}

/*----------------------------------------=[Weapon Tracer]=------------------------------------------*/
public fw_TraceAttackPre(iVictim, iAttacker, Float:fDamage, Float:fDeriction[3], iTraceHandle, iBitDamage) {
	if(!is_user_valid_alive(iAttacker))
		return HAM_IGNORED

	if(get_user_weapon(iAttacker) != CSW_ELITE || !g_elemental[iAttacker]) 
		return HAM_IGNORED

	static frost, rgb[3];
	switch(random_num(0, 100)) {
		case 0..30: {
			rgb = { 0, 100, 255 };
			set_user_weapon_anim(iAttacker, random_num(2, 6));
			frost = true
		}
		default: {
			rgb = { 255, 69, 0 };
			set_user_weapon_anim(iAttacker, random_num(8,12));	
			frost = false
		}
	} 

	if(get_pcvar_num(cvar_tracer)) {
		static Float:end[3], Float:start[3], Float:player_origin[3], Float:player_view_offset[3];
		static Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:gun_position[3];

		// Hand Position
		if(!is_user_bot(iAttacker))
			query_client_cvar(iAttacker, "cl_righthand" , "get_righthand")

		// Start origin
		global_get(glb_v_forward, v_forward);
		global_get(glb_v_right, v_right);
		global_get(glb_v_up, v_up);
		pev(iAttacker, pev_origin, player_origin);
		pev(iAttacker, pev_view_ofs, player_view_offset);
		xs_vec_add(player_origin, player_view_offset, gun_position);
		xs_vec_mul_scalar(v_forward, 16.0, v_forward);

		if(righthand[iAttacker])
			xs_vec_mul_scalar(v_right, frost ? -3.0 : 3.0, v_right);
		else
			xs_vec_mul_scalar(v_right, frost ? 3.0 : -3.0, v_right);

		xs_vec_mul_scalar(v_up, -2.75, v_up);
		xs_vec_add(gun_position, v_forward, start);
		xs_vec_add(start, v_right, start);
		xs_vec_add(start, v_up, start);

		// End Origin
		free_tr2(iTraceHandle);
		get_tr2(iTraceHandle, TR_vecEndPos, end)

		// Tracer
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(0)    //TE_BEAMENTPOINTS 0
		engfunc(EngFunc_WriteCoord, start[0])
		engfunc(EngFunc_WriteCoord, start[1])
		engfunc(EngFunc_WriteCoord, start[2])
		engfunc(EngFunc_WriteCoord, end[0])
		engfunc(EngFunc_WriteCoord, end[1])
		engfunc(EngFunc_WriteCoord, end[2])
		write_short(tracer_spr)
		write_byte(1) // framestart
		write_byte(5) // framerate
		write_byte(2) // life
		write_byte(5) // width
		write_byte(0) // noise
		write_byte(rgb[0])// r, g, b
		write_byte(rgb[1])// r, g, b
		write_byte(rgb[2])// r, g, b
		write_byte(200) // brightness
		write_byte(150) // speed
		message_end()
	}

	if(!is_user_valid_alive(iVictim))
		return HAM_IGNORED

	if(!zp_get_user_zombie(iVictim))
		return HAM_IGNORED

	SetHamParamFloat(3, fDamage * get_pcvar_float(cvar_dmgmultiplier))

	if(frost) {
		if(!zp_get_zombie_special_class(iVictim)) {
			zp_set_user_frozen(iVictim, true)
			set_task(get_pcvar_float(cvar_fr_duration),"removefrost", iVictim)
		}
		set_aura_effect(iVictim, 0, 100, 255, 50) 
	}
	else {
		set_aura_effect(iVictim, 255, 69, 0, 50) 
		zp_set_user_burn(iVictim, true);
		set_task(get_pcvar_float(cvar_f_duration),"removefire", iVictim)
	}

	return HAM_IGNORED
}
/*----------------------------------=[Get User Hand Position]=------------------------------------*/
public get_righthand(id, const szCvar[], const szValue[]) {
	if(str_to_num(szValue) == 1)
		righthand[id] = true
	else 
		righthand[id] = false
}
/*----------------------------------=[Action on Choose the Item]=------------------------------------*/
public zp_extra_item_selected_pre(player, itemid)
{
	if (itemid == g_itemid) 
	{
		new szText[16]
		formatex(szText, charsmax(szText), "\r[%d/%d]", g_buy_limit, get_pcvar_num(cvar_limit))
		zp_extra_item_textadd(szText)

		if(g_elemental[player] || g_buy_limit >= get_pcvar_num(cvar_limit))
			return ZP_PLUGIN_HANDLED

	}
	return PLUGIN_CONTINUE
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid) 
	{
		drop_prim(player)
		g_elemental[player] = true
		client_printcolor(player,"/g[ZP]/y You Bought the /tElemental /g[Fire & Ice]")
		give_item(player, "weapon_elite")
		g_buy_limit++
	}
}


/*------------------------------------=[Remove fire/frost]=-------------------------------------*/
public removefire(plr) zp_set_user_burn(plr, false)
public removefrost(plr) zp_set_user_frozen(plr, false)

/*--------------------------------------------=[Stocks]=---------------------------------------------*/
stock set_aura_effect(id, r, g, b, size)
{
	static Float:originF3[3]; pev(id, pev_origin, originF3)
	
	// Efeito da Aura
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF3, 0)
	write_byte(TE_DLIGHT) // TE id
	engfunc(EngFunc_WriteCoord, originF3[0]) // x
	engfunc(EngFunc_WriteCoord, originF3[1]) // y
	engfunc(EngFunc_WriteCoord, originF3[2]) // z
	write_byte(size) // radio
	write_byte(r) // r
	write_byte(g) // g
	write_byte(b) // b
	write_byte(30) // vida en 0.1, 30 = 3 segundos
	write_byte(30) // velocidad de decaimiento
	message_end() 
}

stock drop_prim(id) 
{
	new weapons[32], num
	get_user_weapons(id, weapons, num)
	for (new i = 0; i < num; i++) 
	{
		if (SECONDARY_BIT_SUM & (1<<weapons[i])) 
		{
			static wname[32]
			get_weaponname(weapons[i], wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock find_ent_by_owner(index, const classname[], owner, jghgtype = 0) {
	new strtype[11] = "classname", ent = index;
	switch (jghgtype) {
		case 1: strtype = "target";
		case 2: strtype = "targetname";
	}

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, strtype, classname)) && pev(ent, pev_owner) != owner) {}

	return ent;
}

stock set_user_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock give_item(index, const item[]) 
{
	if (!equal(item, "weapon_", 7) && !equal(item, "ammo_", 5) && !equal(item, "item_", 5) && !equal(item, "tf_weapon_", 10))
		return 0;

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, item));
	
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
	new msg[191], players[32], count = 1; vformat(msg,190,input,3);
	replace_all(msg,190,"/g","^4");    // green
	replace_all(msg,190,"/y","^1");    // normal
	replace_all(msg,190,"/t","^3");    // team
	    
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
