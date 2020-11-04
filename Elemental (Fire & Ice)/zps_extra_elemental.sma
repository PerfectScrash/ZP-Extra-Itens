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
#include <zombieplague>

native zp_get_user_bombardier(id)
native zp_get_user_assassin(id)
native zp_set_user_frozen(id, bool:IsFrozen, Float:duration)
native zp_set_user_burning(id, bool:IsBurning)

/*-------------------------------=[Variables, Conts, Defines & Cvars]=--------------------------------*/

new EL_V_MODEL[64] = "models/zombie_plague/v_Elemental.mdl"
new EL_P_MODEL[64] = "models/zombie_plague/p_Elemental.mdl"
new EL_W_MODEL[64] = "models/zombie_plague/w_Elemental.mdl"
new EL_OLD_W_MODEL[64] = "models/w_elite.mdl"

new cvar_custommodel, cvar_tracer, cvar_uclip, cvar_fr_duration, cvar_f_duration, cvar_oneround, cvar_dmgmultiplier, cvar_limit
new g_itemid, g_elemental[33], g_zoom[33], bullets[33], tracer_spr, g_buy_limit, g_maxplayers

const SECONDARY_BIT_SUM = (1<<CSW_USP)|(1<<CSW_DEAGLE)|(1<<CSW_GLOCK18)|(1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)

#define ITEM_NAME "Elemental \r[Fire & Ice]"
#define ITEM_COST 40

#define is_user_valid_alive(%1) (1 <= %1 <= g_maxplayers && is_user_alive(%1))

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
	register_event("CurWeapon", "event_CurWeapon", "b", "1=1") 
	register_event("CurWeapon","checkWeapon","be","1=1")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("CurWeapon", "make_tracer", "be", "1=1", "3>0")
	
	// Forwards
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Ham TakeDamage
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
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
public client_connect(id) g_elemental[id] = false
public client_disconnect(id) g_elemental[id] = false
public Death() g_elemental[read_data(2)] = false
public zp_user_infected_post(id) g_elemental[id] = false
public zp_user_humanized_post(id) g_elemental[id] = false

public event_round_start() 
{
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
public checkWeapon(id)
{
	new plrClip, plrAmmo, plrWeap[32], plrWeapId

	plrWeapId = get_user_weapon(id, plrClip , plrAmmo)
	
	if (plrWeapId == CSW_ELITE && g_elemental[id]) event_CurWeapon(id)
	else return PLUGIN_CONTINUE
	
	if (plrClip == 0 && get_pcvar_num(cvar_uclip))
	{
		// If the user is out of ammo..
		get_weaponname(plrWeapId, plrWeap, 31)
		give_item(id, plrWeap)
		engclient_cmd(id, plrWeap)  // Get the name of their weapon
		engclient_cmd(id, plrWeap)
		engclient_cmd(id, plrWeap)
	}
	return PLUGIN_HANDLED
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

/*-----------------------------------------=[Take Damage]=-------------------------------------------*/
public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if(is_user_valid_alive(attacker) && !zp_get_user_zombie(attacker) && get_user_weapon(attacker) == CSW_ELITE && g_elemental[attacker] && is_user_valid_alive(victim) && zp_get_user_zombie(victim))
	{
		SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmgmultiplier))
		
		switch(random_num(1,100))
		{
			case 1..30: 
			{
				if(!zp_get_user_nemesis(victim) && !zp_get_user_assassin(victim) && !zp_get_user_bombardier(victim)) {
					zp_set_user_frozen(victim, true, get_pcvar_float(cvar_fr_duration))
					set_aura_effect(victim, 0, 100, 255, 50) 
					set_user_tracer(attacker, 0, 100, 255)
					set_user_weapon_anim(attacker, random_num(2,6))
				}
			}
			case 31..100: 
			{
				zp_set_user_burning(victim, true)
				set_aura_effect(victim, 255, 69, 0, 50) 
				set_task(get_pcvar_float(cvar_f_duration),"removefire",victim)
				set_user_tracer(attacker, 255, 69, 0)
				set_user_weapon_anim(attacker, random_num(8,12))
			}
		}
	}
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
public make_tracer(id)
{
	if (get_pcvar_num(cvar_tracer) && is_user_valid_alive(id))
	{
		new clip,ammo, wpnid = get_user_weapon(id,clip,ammo), pteam[16]
		get_user_team(id, pteam, 15)
		
		static iVictim, iDummy
		get_user_aiming(id, iVictim, iDummy, 9999);
		
		if(is_user_valid_alive(iVictim)) {
			if ((bullets[id] > clip) && (wpnid == CSW_ELITE) && g_elemental[id] && !zp_get_user_zombie(iVictim))
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
public zp_extra_item_selected(player, itemid)
{
	// check if the selected item matches any of our registered ones
	if (itemid == g_itemid) 
	{
		if(g_elemental[player])
		{
			client_printcolor(player, "/g[ZP]/y You already have the Elemental")
			return ZP_PLUGIN_HANDLED
		}
		if (!zp_has_round_started())
		{
			client_printcolor(player, "/g[ZP]/y Wait the round begins...")
			return ZP_PLUGIN_HANDLED
		}
		if(g_buy_limit >= get_pcvar_num(cvar_limit))
		{
			client_printcolor(player, "/g[ZP]/y This Item Only can buy /t%d/y Times per Round.", get_pcvar_num(cvar_limit))
			return ZP_PLUGIN_HANDLED
		}
		else
		{
			drop_prim(player)
			g_elemental[player] = true
			client_printcolor(player,"/g[ZP]/y You Bought the /tElemental /g[Fire & Ice]")
			give_item(player, "weapon_elite")
		}
	}
	return PLUGIN_CONTINUE
}


/*------------------------------------=[Remove fire]=-------------------------------------*/
public removefire(plr) zp_set_user_burning(plr, false)

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
