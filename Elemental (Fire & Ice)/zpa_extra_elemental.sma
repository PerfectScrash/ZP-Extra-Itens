/*-----------------------------------------------------------------------------------------------------
				[Elemental Fire & Ice | Credits:]
				
		* [P]erfec[T] [S]cr[@]s[H]: For ZP 4.3, ZPA, ZP Shade, ZP Special Version
		* metallicawOw: Thanks for the Nitrogen Galil's Code
		* Javivi: Thanks for the Flame XM1014's Code
		* Catastrophe: For ZP 5.0 Version
		* Nightmare: For Elemental Weapon Model
		* Sergio #: For Fixed Some Bugs
------------------------------------------------------------------------------------------------------*/

/*------------------------------------------=[Includes]=--------------------------------------------*/
#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <zombie_plague_advance> 

/*-------------------------------=[Variables, Conts, Defines & Cvars]=-------------------------------*/

new g_itemid, g_elemental[33], g_frozen[33], frost_spr, bullets[33], g_zoom[33], g_buy_limit, g_maxplayers
new tracer_spr, fire_spr, smoke_spr, g_burning[33], burn_time[33]

// Cvars
new cvar_frosttime, cvar_dmgmultiplier, cvar_burndmg, cvar_burntime, cvar_burn_nemesis_time,
cvar_delay, cvar_minhealth, cvar_custommodel, cvar_uclip, cvar_tracer, cvar_oneround, cvar_limit

const SECONDARY_BIT_SUM = (1<<CSW_USP)|(1<<CSW_DEAGLE)|(1<<CSW_GLOCK18)|(1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)

#define ITEM_NAME "Elemental \r[Fire & Ice]"
#define ITEM_COST 40

#define is_user_valid_alive(%1) (1 <= %1 <= g_maxplayers && is_user_alive(%1))

// ZP default Burn sounds
new const burn_sounds[][] = { "zombie_plague/zombie_burn3.wav", "zombie_plague/zombie_burn4.wav", "zombie_plague/zombie_burn5.wav",
"zombie_plague/zombie_burn6.wav", "zombie_plague/zombie_burn7.wav" }

new EL_V_MODEL[64] = "models/zombie_plague/v_Elemental.mdl"
new EL_P_MODEL[64] = "models/zombie_plague/p_Elemental.mdl"
new EL_W_MODEL[64] = "models/zombie_plague/w_Elemental.mdl"
new EL_OLD_W_MODEL[64] = "models/w_elite.mdl"

/*---------------------------------------=[Plugin Register]=-----------------------------------------*/
public plugin_init()
{
	// Plugin Register
	register_plugin("[ZP] Extra Item: Elemental", "1.3", "[P]erfec[T] [S]cr[@]s[H]")
	register_cvar("zp_elemental", "1.3", FCVAR_SERVER|FCVAR_SPONLY)
	
	// Cvar Register
	cvar_dmgmultiplier = register_cvar("zp_elemental_dmg_multiplier", "3")    	  // Elemental Damage Multipler
	cvar_custommodel = register_cvar("zp_elemental_custom_model", "1")  		  // Custom Model (0 - Off | 1 - On)
	cvar_uclip = register_cvar("zp_elemental_unlimited_clip", "1")        		  // Unlimited Clip (0 - Off | 1 - On)
	cvar_tracer = register_cvar("zp_elemental_tracers", "1")           		  // Tracer? (0 - Off | 1 - On)
	cvar_frosttime = register_cvar("zp_elemental_frost_time", "5.0")        		  // Time will be frozen
	cvar_burndmg = register_cvar("zp_elemental_fire_dmg", "10")      		  // Fire Damage (When burning the zm)
	cvar_burntime = register_cvar("zp_elemental_fire_time", "12")        		  // Time will be burning
	cvar_burn_nemesis_time = register_cvar("zp_elemental_fire_nem_time", "5")	  // Time the Nemesis / Assassin wrath Staying Burning
	cvar_delay = register_cvar("zp_elemental_delay", "4.0")            		  // Time that led to the zm be burned again
	cvar_minhealth = register_cvar("zp_elemental_fire_minhp", "50")        		  // Minimum HP for Zombie Burn
	cvar_oneround = register_cvar("zp_elemental_one_round", "1")       		  // The Elemental should be 1 round? (1 - On | 0 - Off)
	cvar_limit = register_cvar("zp_elemental_buy_limit", "3")			  // Buy Limit Per Round
	
	// Item Register
	g_itemid = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN)
	
	// Events
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("CurWeapon", "event_CurWeapon", "b", "1=1") 
	register_event("CurWeapon","checkWeapon","be","1=1")
	register_event("CurWeapon", "make_tracer", "be", "1=1", "3>0")
	
	// Forwards
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	
	// Hams
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1 )
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_elite", "fw_AddToPlayer")
	
	g_maxplayers = get_maxplayers()
}

/*------------------------------------------=[Precaches]=--------------------------------------------*/
public plugin_precache() 
{
	// Models
	precache_model(EL_V_MODEL)
	precache_model(EL_P_MODEL)
	precache_model(EL_W_MODEL)
	precache_model(EL_OLD_W_MODEL)
	
	// Sounds
	precache_sound("warcraft3/impalehit.wav");
	
	// Tracer Spr
	tracer_spr = precache_model("sprites/dot.spr")
	
	precache_sound("weapons/zoom.wav")
	
	// Ice Spr
	frost_spr = precache_model("sprites/shockwave.spr");
	
	// Fire Spr
	fire_spr = precache_model("sprites/flame.spr")
	smoke_spr = precache_model("sprites/black_smoke3.spr")
	
	// Sound of Burning Zombies
	for(new i = 0; i < sizeof burn_sounds; i++) precache_sound(burn_sounds[i])
}

/*---------------------------------------=[Bug Prevention]=-----------------------------------------*/
public event_round_start()
{
	if(get_pcvar_num(cvar_oneround))
	{
		for (new i = 1; i <= g_maxplayers; i++)
		{
			g_elemental[i] = false
			RemoveFrost(i)
		}
	}
	
	g_buy_limit = 0
}

public fw_PlayerSpawn_Post(victim, attacker, shouldgib) RemoveFrost(victim)

public client_putinserver(id)
{
	g_elemental[id] = false
	RemoveFrost(id)
}

public client_disconnect(id)
{
	g_elemental[id] = false
	RemoveFrost(id)
}

public client_connect(id)
{
	g_elemental[id] = false
	RemoveFrost(id)
}

public zp_user_humanized_post(id, human)
{
	g_elemental[id] = false
	RemoveFrost(id)
}

public zp_user_infected_post(id)
{
	g_elemental[id] = false
	RemoveFrost(id)
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
			g_buy_limit++
		}
	}
	return PLUGIN_CONTINUE
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

/*-----------------------------------------=[Take Damage]=-------------------------------------------*/
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(is_user_valid_alive(attacker) && g_elemental[attacker] && get_user_weapon(attacker) == CSW_ELITE)
	{
		SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmgmultiplier))
		
		switch(random_num(0,100))
		{
			case 0..30: set_user_frozen(victim), set_user_tracer(attacker, 0, 100, 255), set_user_weapon_anim(attacker, random_num(2,6))
			case 31..100: set_user_burn(victim), set_user_tracer(attacker, 255, 69, 0), set_user_weapon_anim(attacker, random_num(8,12))
		}
	}

	return PLUGIN_CONTINUE
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

/*-------------------------------------=[Frozen Power and Effects]=-----------------------------------*/
public fw_PlayerPreThink(id)
{
	// Not alive
	if (!is_user_valid_alive(id) || !zp_get_user_zombie(id)) return;

	// Set Player MaxSpeed
	if (g_frozen[id]) 
	{
		set_pev(id, pev_velocity, Float:{0.0,0.0,0.0}) // stop motion
		set_pev(id, pev_maxspeed, 1.0) // prevent from moving
	}
}  

// Set user Frozen
public set_user_frozen(id)
{
	if(is_user_valid_alive(id) && zp_get_user_zombie(id) && !zp_get_user_nemesis(id) && !zp_get_user_assassin(id) && !g_frozen[id])
	{
		// For Frost Effect Ring
		static Float:originF3[3]; 
		pev(id, pev_origin, originF3)
		
		// Screen Fade
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, id)
		write_short((1<<12)*1) // duration
		write_short((1<<12)*1) // hold time
		write_short(0x0000) // fade type
		write_byte(0) // red
		write_byte(50) // green
		write_byte(200) // blue
		write_byte(100) // alpha
		message_end()
		
		// Largest ring
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF3, 0)
		write_byte(TE_BEAMCYLINDER) // TE id
		engfunc(EngFunc_WriteCoord, originF3[0]) // x
		engfunc(EngFunc_WriteCoord, originF3[1]) // y
		engfunc(EngFunc_WriteCoord, originF3[2]) // z
		engfunc(EngFunc_WriteCoord, originF3[0]) // x axis
		engfunc(EngFunc_WriteCoord, originF3[1]) // y axis
		engfunc(EngFunc_WriteCoord, originF3[2]+100.0) // z axis
		write_short(frost_spr) // sprite
		write_byte(0) // startframe
		write_byte(0) // framerate
		write_byte(4) // life
		write_byte(60) // width
		write_byte(0) // noise
		write_byte(41) // red
		write_byte(138) // green
		write_byte(255) // blue
		write_byte(200) // brightness
		write_byte(0) // speed
		message_end()
		
		// Aura Effect
		set_aura_effect(id, 0, 100, 255, 50) 
		
		// Light blue glow while frozen
		fm_set_rendering(id, kRenderFxGlowShell, 0, 100, 200, kRenderNormal, 25)
		
		g_frozen[id] = true
		set_task(get_pcvar_float(cvar_frosttime), "RemoveFrost", id) // Time to Remove Frost Effect 
		emit_sound(id, CHAN_WEAPON, "warcraft3/impalehit.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
}

// Remove Frost Effect
public RemoveFrost(id)
{
	// Not alive or not frozen anymore
	if (!is_user_valid_alive(id) || !g_frozen[id]) return;
	
	g_frozen[id] = false; // Unfreeze
	fm_set_rendering(id) // Remove glow
}

/*-------------------------------------=[Flame Power and Effects]=-----------------------------------*/
public set_user_burn(victim)
{
	if(is_user_valid_alive(victim) && zp_get_user_zombie(victim))
	{
		if(!g_burning[victim] && get_user_health(victim) > get_pcvar_num(cvar_minhealth))
		{
			// Time Nemesis and Assassin Pro Stick Burning
			if(zp_get_user_nemesis(victim) || zp_get_user_assassin(victim)) burn_time[victim] = get_pcvar_num(cvar_burn_nemesis_time)
			else burn_time[victim] = get_pcvar_num(cvar_burntime)
						
			g_burning[victim] = true // Burn / ON
			set_burn_flame(victim) // Burn victim
						
						
			// Emit burn sound      
			emit_sound(victim, CHAN_VOICE, burn_sounds[random_num(0, sizeof burn_sounds - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM )  
		}
		set_aura_effect(victim, 255, 69, 0, 50)
	}
}

public set_burn_flame(victim)
{
	// Get user origin
	static Origin[3]; get_user_origin(victim, Origin)
	
	// If burn time is over or victim are in water
	if(burn_time[victim] <= 0 || pev(victim, pev_flags) & FL_INWATER)
	{   
		// Show Smoke sprite   
		message_begin(MSG_PVS, SVC_TEMPENTITY, Origin)
		write_byte(TE_SMOKE) // TE id
		write_coord(Origin[0]) // x
		write_coord(Origin[1]) // y
		write_coord(Origin[2]-50) // z
		write_short(smoke_spr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		// Delay to allow burn again
		set_task(get_pcvar_float(cvar_delay), "Stop", victim)
		
		return
	}
	else
	{      
		// At half-burntime
		if(get_pcvar_num(cvar_burntime) * 0.5 == burn_time[victim]) emit_sound(victim, CHAN_VOICE, burn_sounds[random_num(0, charsmax(burn_sounds))], 1.0, ATTN_NORM, 0, PITCH_NORM) // Play another sound
		
		// Flame sprite   
		message_begin(MSG_PVS, SVC_TEMPENTITY, Origin)
		write_byte(TE_SPRITE) // TE id
		write_coord(Origin[0]+random_num(-5, 5)) // x
		write_coord(Origin[1]+random_num(-5, 5)) // y
		write_coord(Origin[2]+random_num(-10, 10)) // z
		write_short(fire_spr) // sprite
		write_byte(random_num(5, 10)) // scale
		write_byte(200) // brightness
		message_end()
		
		// Decrease Time
		burn_time[victim]--
		
		// Decrease life (random)
		set_user_health(victim, get_user_health(victim) - get_pcvar_num(cvar_burndmg))
		
		// Stop fire if health <= min health.
		if(get_user_health(victim) <= get_pcvar_num(cvar_minhealth))
		{
			g_burning[victim] = false
			return
		}
		
		// Repeat
		set_task(0.5, "set_burn_flame", victim)
	}
}

public Stop(victim) g_burning[victim] = false // Allow burn again

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

/*---------------------------------------------=[Stocks]=--------------------------------------------*/
// Glow Without using the Include fakemeta_util
stock fm_set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
	static Float:color[3]
	color[0] = float(r)
	color[1] = float(g)
	color[2] = float(b)
	
	set_pev(entity, pev_renderfx, fx)
	set_pev(entity, pev_rendercolor, color)
	set_pev(entity, pev_rendermode, render)
	set_pev(entity, pev_renderamt, float(amount))
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

stock set_user_health(index, health) 
{
	health > 0 ? set_pev(index, pev_health, float(health)) : dllfunc(DLLFunc_ClientKill, index);
	return 1;
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

stock set_user_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

// Colored Chat (client_printcolor)
stock client_printcolor(const id, const input[], any:...)
{
	new count = 1, players[32]
	static msg[191]
	vformat(msg, 190, input, 3)
	
	replace_all(msg, 190, "/g", "^4")  // Green Chat
	replace_all(msg, 190, "/y", "^1")  // Normal Chat
	replace_all(msg, 190, "/t", "^3")  // Team Chat
	
	if (id) players[0] = id; else get_players(players, count, "ch")
	{
		for (new i = 0; i < count; i++)
		{
			if (is_user_connected(players[i]))
			{
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
}
