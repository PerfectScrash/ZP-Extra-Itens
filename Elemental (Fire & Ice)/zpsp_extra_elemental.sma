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
#include <hamsandwich>
#include <zombie_plague_special>

#if ZPS_INC_VERSION < 45
	#assert Zombie Plague Special 4.5 Include File Required. Download Link: https://forums.alliedmods.net/showthread.php?t=260845
#endif

/*-------------------------------=[Variables, Conts, Defines & Cvars]=--------------------------------*/

new EL_V_MODEL[64] = "models/zombie_plague/v_Elemental.mdl"
new EL_P_MODEL[64] = "models/zombie_plague/p_Elemental.mdl"
new EL_W_MODEL[64] = "models/zombie_plague/w_Elemental.mdl"
new EL_OLD_W_MODEL[64] = "models/w_elite.mdl"
const Weapon_Key = 324584

new cvar_custommodel, cvar_tracer, cvar_uclip, cvar_fr_duration, cvar_f_duration, cvar_oneround, cvar_dmgmultiplier, cvar_limit
new g_itemid, g_elemental[33], g_zoom[33], bullets[33], tracer_spr, g_buy_limit

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

#define is_user_valid_alive(%1) (1 <= %1 <= MaxClients && is_user_alive(%1))

// Max Clip for weapons
new const MAXCLIP[] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 }
/*---------------------------------------=[Plugin Register]=-----------------------------------------*/
public plugin_init()
{	
	// Register The Plugin
	register_plugin("[ZP] Extra: Elemental", "1.3", "Catastrophe | [P]erfec[T] [S]cr[@]s[H]")
	register_cvar("zp_elemental", "1.3", FCVAR_SERVER|FCVAR_SPONLY)
	
	// Register Zombie Plague extra item
	g_itemid = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN)
	
	// Death Msg
	// register_event("CurWeapon", "event_CurWeapon", "b", "1=1") 
	register_message(get_user_msgid("CurWeapon"), "message_cur_weapon")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("CurWeapon", "make_tracer", "be", "1=1", "3>0")
	
	// Forwards
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Ham TakeDamage
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, "weapon_elite", "fw_AddToPlayer")
	
	// Cvars
	cvar_dmgmultiplier = register_cvar("zp_elemental_dmg_multiplier", "3")   // Elemental Damage Multipler
	cvar_custommodel = register_cvar("zp_elemental_custom_model", "1")	// Custom Model (0 - Off | 1 - On)
	cvar_uclip = register_cvar("zp_elemental_unlimited_clip", "1")		// Unlimited Clip (0 - Off | 1 - On)
	cvar_fr_duration = register_cvar("zp_elemental_frost_time", "5.0")	// Time will be frozen
	cvar_f_duration = register_cvar("zp_elemental_fire_time", "12")		// Time will be burning
	cvar_tracer = register_cvar("zp_elemental_tracers", "1")			// Tracer? (0 - Off | 1 - On)
	cvar_oneround = register_cvar("zp_elemental_one_round", "1")		// The Elemental should be 1 round? (1 - On | 0 - Off)
	cvar_limit = register_cvar("zp_elemental_buy_limit", "3")		// Buy Limit Per Round
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
public client_disconnected(id) g_elemental[id] = false;
public fw_PlayerKilled_Post(victim) g_elemental[victim] = false;
public zp_user_infected_post(id) g_elemental[id] = false;
public zp_user_humanized_post(id) g_elemental[id] = false;

public event_round_start() 
{
	g_buy_limit = 0
	if(get_pcvar_num(cvar_oneround)) {
		static id;
		for(id = 1; id <= MaxClients; id++) 
			g_elemental[id] = false
	}		
}

/*----------------------------------------=[Custom Model]=-------------------------------------------*/
public zp_fw_deploy_weapon(id, wpnid)
{
	if (!is_user_valid_alive(id)) 
		return PLUGIN_CONTINUE;

	if(!g_elemental[id])
		return PLUGIN_CONTINUE

	if(zp_get_user_zombie(id) || !get_pcvar_num(cvar_custommodel))
		return PLUGIN_CONTINUE
	
	if (wpnid == CSW_ELITE) {
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
		set_pev(wpn, pev_impulse, Weapon_Key)
		engfunc(EngFunc_SetModel, entity, EL_W_MODEL)
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(wpn, id)
{
	if(pev_valid(wpn) && is_user_connected(id) && pev(wpn, pev_impulse) == Weapon_Key)
	{
		g_elemental[id] = true
		set_pev(wpn, pev_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

/*-----------------------------------------=[Take Damage]=-------------------------------------------*/
public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if(!is_user_valid_alive(attacker) || !is_user_valid_alive(victim))
		return HAM_IGNORED;

	if(zp_get_user_zombie(attacker) || !g_elemental[attacker] || !zp_get_user_zombie(victim))
		return HAM_IGNORED
	
	if(get_user_weapon(attacker) != CSW_ELITE)
		return HAM_IGNORED
	
	SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmgmultiplier))
	if(random_num(1, 100) <= 30 && !zp_get_zombie_special_class(victim)) {
		zp_set_user_frozen(victim, SET, get_pcvar_float(cvar_fr_duration))
		set_aura_effect(victim, 0, 100, 255, 50) 
		set_user_tracer(attacker, 0, 100, 255)
		set_user_weapon_anim(attacker, random_num(2, 6))
	}
	else {
		zp_set_user_burn(victim, SET, get_pcvar_float(cvar_f_duration))
		set_aura_effect(victim, 255, 69, 0, 50) 
		set_user_tracer(attacker, 255, 69, 0)
		set_user_weapon_anim(attacker, random_num(8, 12))
	}

	return HAM_IGNORED
}

/*-----------------------------------------=[Weapon Zoom]=-------------------------------------------*/
public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_valid_alive(id))
		return PLUGIN_CONTINUE

	static szClip, szAmmo, szWeapID
	szWeapID = get_user_weapon(id, szClip, szAmmo)

	if(zp_get_user_zombie(id) || szWeapID != CSW_ELITE && g_zoom[id]) 
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
public make_tracer(id)
{
	if (get_pcvar_num(cvar_tracer) && is_user_valid_alive(id))
	{
		new clip,ammo, wpnid = get_user_weapon(id,clip,ammo), pteam[16]
		get_user_team(id, pteam, 15)
		
		static iVictim, iDummy
		get_user_aiming(id, iVictim, iDummy, 9999);
		
		if(!is_user_valid_alive(iVictim)) {
			if ((bullets[id] > clip) && (wpnid == CSW_ELITE) && g_elemental[id])
			{
				new vec1[3], vec2[3], rgb[3]
				get_user_origin(id, vec1, 1) // origin; your camera point.
				get_user_origin(id, vec2, 4) // termina; where your bullet goes (4 is cs-only)
							
				switch(random_num(0,100))
				{
					case 1..30: rgb[0] = 0, rgb[1] = 100, rgb[2] = 255, set_user_weapon_anim(id, random_num(2,6))
					case 31..100: rgb[0] = 255, rgb[1] = 69, rgb[2] = 0, set_user_weapon_anim(id, random_num(8,12))			
				} 
	
				set_user_tracer(id, rgb[0], rgb[1], rgb[2])
			}
		}
		bullets[id] = clip
	}
}

public set_user_tracer(id, R, G, B)
{
	if (get_pcvar_num(cvar_tracer) && is_user_valid_alive(id))
	{
		new vec1[3], vec2[3]
		get_user_origin(id, vec1, 1) // origin; your camera point.
		get_user_origin(id, vec2, 4) // termina; where your bullet goes (4 is cs-only)

		//BEAMENTPOINTS
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte (0)    //TE_BEAMENTPOINTS 0
		write_coord(vec1[0])
		write_coord(vec1[1])
		write_coord(vec1[2])
		write_coord(vec2[0])
		write_coord(vec2[1])
		write_coord(vec2[2])
		write_short(tracer_spr)
		write_byte(1) // framestart
		write_byte(5) // framerate
		write_byte(2) // life
		write_byte(10) // width
		write_byte(0) // noise
		write_byte(R) // r, g, b
		write_byte(G) // r, g, b
		write_byte(B) // r, g, b
		write_byte(200) // brightness
		write_byte(150) // speed
		message_end()
	}
}
/*----------------------------------=[Action on Choose the Item]=------------------------------------*/
public zp_extra_item_selected_pre(player, itemid)
{
	if (itemid != g_itemid) 
		return PLUGIN_CONTINUE
	
	zp_extra_item_textadd(fmt("\r[%d/%d]", g_buy_limit, get_pcvar_num(cvar_limit)))

	if(g_elemental[player] || g_buy_limit >= get_pcvar_num(cvar_limit))
		return ZP_PLUGIN_HANDLED

	
	return PLUGIN_CONTINUE
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid != g_itemid) 
		return;
	
	zp_drop_weapons(player, WPN_SECONDARY)
	g_elemental[player] = true
	client_print_color(player, print_team_default, "^4[ZP]^1 You Bought the ^3Elemental ^4[Fire & Ice]")
	zp_give_item(player, "weapon_elite", 1)
	g_buy_limit++
}

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
