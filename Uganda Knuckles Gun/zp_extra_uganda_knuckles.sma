#include <amxmodx>
#include <engine>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <zombieplague>

#define ENG_NULLENT		-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define UGANDA_WPN_KEY	312312
#define MAX_PLAYERS  			  32
#define IsValidUser(%1) (1 <= %1 <= g_MaxPlayers)

const USE_STOPPED = 0
const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 4
const OFFSET_LINUX_WEAPONS = 4

#define WEAP_LINUX_XTRA_OFF			4
#define m_fKnown				44
#define m_flNextPrimaryAttack 			46
#define m_flTimeWeaponIdle			48
#define m_iClip					51
#define m_fInReload				54
#define PLAYER_LINUX_XTRA_OFF			4
#define m_flNextAttack				83

#define RELOAD_TIME 2.9
#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_m4a1",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_sg550", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

new const WPN_Sounds[][] = { 
	"zp_uganda_scrash/sonic_ring.wav",
	"zp_uganda_scrash/oh_no.wav",
	"zp_uganda_scrash/emerald.wav"
}

new V_MODEL[64] = "models/zp_uganda_scrash/v_uganda_knuckles.mdl"
new P_MODEL[64] = "models/zp_uganda_scrash/p_uganda_knuckles.mdl"
new W_MODEL[64] = "models/zp_uganda_scrash/w_uganda_knuckles.mdl"

new RING_MODEL[64] = "models/zp_uganda_scrash/ring.mdl"
new RING_NAME[32] = "uganda_ring"

new cvar_dmg_uganda, cvar_recoil_uganda, g_itemid_uganda, cvar_clip_uganda, cvar_uganda_ammo , cvar_uganda_life , cvar_uganda_speed
new g_has_uganda[33]//, cvar_fire_rate
new g_MaxPlayers, g_orig_event_uganda, g_clip_ammo[33]
new Float:cl_pushangle[MAX_PLAYERS + 1][3], m_iBlood[2]
new g_uganda_TmpClip[33] , g_dmg[33], g_IsInPrimaryAttack = 0

public plugin_init()
{
	register_plugin("[ZP] Extra Item: Uganda Knuckles Gun", "1.0", "Crock / =) | Perfect Scrash")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_ump45", "fw_uganda_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ump45", "fw_uganda_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ump45", "fw_uganda_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, "weapon_ump45", "uganda_ItemPostFrame");
	RegisterHam(Ham_Weapon_Reload, "weapon_ump45", "uganda_Reload");
	RegisterHam(Ham_Weapon_Reload, "weapon_ump45", "uganda_Reload_Post", 1);
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)

	cvar_dmg_uganda = register_cvar("zp_uganda_dmg", "90.0")
	cvar_recoil_uganda = register_cvar("zp_uganda_recoil", "0.3")
	cvar_clip_uganda = register_cvar("zp_uganda_clip", "30")
	cvar_uganda_ammo = register_cvar("zp_uganda_ammo", "180")
	cvar_uganda_life = register_cvar("zp_uganda_ringlife", "2.0")
	cvar_uganda_speed = register_cvar("zp_uganda_ringspeed", "2100")
	//cvar_fire_rate = register_cvar("zp_uganda_fire_rate", "0.1")

	register_touch(RING_NAME, "*" ,"ring_touch" )
	register_think(RING_NAME,"remove_ring")

	g_itemid_uganda = zp_register_extra_item("Uganda Knuckles Gun", 80, ZP_TEAM_HUMAN)
	g_MaxPlayers = get_maxplayers()
}
public plugin_precache()
{
	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(RING_MODEL)

	for(new i = 0; i < sizeof WPN_Sounds; i++)
		precache_sound(WPN_Sounds[i])

	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/ump45.sc", name))
	{
		g_orig_event_uganda = get_orig_retval()
		return FMRES_HANDLED
	}
	
	return FMRES_IGNORED
}



public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED;
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED;
	
	static iOwner
	
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, "models/w_ump45.mdl"))
	{
		static iStoredSVDID
		
		iStoredSVDID = find_ent_by_owner(ENG_NULLENT, "weapon_ump45", entity)
	
		if(!is_valid_ent(iStoredSVDID))
			return FMRES_IGNORED;

		if(g_has_uganda[iOwner] && get_user_weapon(iOwner) == CSW_UMP45)
		{
			entity_set_int(iStoredSVDID, EV_INT_WEAPONKEY, UGANDA_WPN_KEY)
			g_has_uganda[iOwner] = false
			
			entity_set_model(entity, W_MODEL)
			
			return FMRES_SUPERCEDE;
		}
	}
	
	
	return FMRES_IGNORED;
}
public give_uganda(id)
{
	drop_weapons(id, 1);
	new iWep2 = fm_give_item(id,"weapon_ump45")
	if( iWep2 > 0 )
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_uganda))
		cs_set_user_bpammo (id, CSW_UMP45, get_pcvar_num(cvar_uganda_ammo))
	}
	g_has_uganda[id] = true;
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid != g_itemid_uganda)
		return PLUGIN_CONTINUE;

	if(g_has_uganda[id]) {
		client_print_color(id, print_team_default, "^4[ZP]^3 You alterady have this item")
		return ZP_PLUGIN_HANDLED
	}

	give_uganda(id)

	return PLUGIN_CONTINUE;
}

public ring_touch(ptr, ptd)
{
	if(!is_valid_ent(ptr))
		return;

	new attacker = entity_get_edict(ptr, EV_ENT_owner)

	static Float:plrViewAngles[3], Float:VecEnd[3], Float:VecDir[3], Float:PlrOrigin[3];
	pev(ptr, pev_v_angle, plrViewAngles);

	static Float:VecSrc[3], Float:VecDst[3];
	
	//VecSrc = pev->origin + pev->view_ofs;
	pev(ptr, pev_origin, PlrOrigin)
	pev(ptr, pev_view_ofs, VecSrc)
	xs_vec_add(VecSrc, PlrOrigin, VecSrc)

	//VecDst = VecDir * 8192.0;
	angle_vector(plrViewAngles, ANGLEVECTOR_FORWARD, VecDir);
	xs_vec_mul_scalar(VecDir, 8192.0, VecDst);
	xs_vec_add(VecDst, VecSrc, VecDst);
	
	new hTrace = create_tr2()
	engfunc(EngFunc_TraceLine, VecSrc, VecDst, 0, ptr, hTrace)
	get_tr2(hTrace, TR_vecEndPos, VecEnd);

	if(is_user_alive(ptd))
	{
		if(zp_get_user_zombie(ptd) && entity_get_edict(ptr, EV_ENT_owner) != ptd) {
			static Float:dmg, hitGroup
			dmg = get_pcvar_float(cvar_dmg_uganda)
			hitGroup = get_tr2(hTrace, TR_iHitgroup);
			switch (hitGroup) {
				case HIT_HEAD: { dmg *= 3.0; }
				case HIT_LEFTARM: { dmg *= 0.9; }
				case HIT_RIGHTARM: { dmg *= 0.9; }
				case HIT_LEFTLEG: { dmg *= 0.9; }
				case HIT_RIGHTLEG: { dmg *= 0.9; }
			}

			g_dmg[ptd] = 1
			ExecuteHamB(Ham_TakeDamage, ptd, attacker, attacker, dmg, DMG_BULLET | DMG_NEVERGIB);
			ExecuteHamB(Ham_TraceBleed, ptd, dmg, VecDir, hTrace, DMG_BULLET | DMG_NEVERGIB);
			make_blood(PlrOrigin, dmg, ptd);

			remove_entity(ptr)
		}
	}

	if(!is_user_alive(ptd)) 
	{
		if(is_valid_ent(ptr))
		{
			entity_set_int(ptr, EV_INT_movetype, 0)
			entity_set_int(ptr, EV_INT_solid, SOLID_NOT)
		}
	}
}


public fw_uganda_AddToPlayer(uganda, id)
{
	if(!is_valid_ent(uganda) || !is_user_connected(id))
		return HAM_IGNORED;
	
	if(entity_get_int(uganda, EV_INT_WEAPONKEY) == UGANDA_WPN_KEY)
	{
		g_has_uganda[id] = true
		
		entity_set_int(uganda, EV_INT_WEAPONKEY, 0)
		
		return HAM_HANDLED;
	}
	
	return HAM_IGNORED;
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if (use_type == USE_STOPPED && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id)
{
	replace_weapon_models(id, read_data(2))
}

replace_weapon_models(id, weaponid)
{
	switch (weaponid)
	{
		case CSW_UMP45:
		{
			if (zp_get_user_zombie(id) || zp_get_user_survivor(id))
				return;
			
			if(g_has_uganda[id])
			{
				set_pev(id, pev_viewmodel2, V_MODEL)
				set_pev(id, pev_weaponmodel2, P_MODEL)
			}
		}
	}
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player))
		return FMRES_IGNORED

	if(zp_get_user_zombie(Player) || (get_user_weapon(Player) != CSW_UMP45) || !g_has_uganda[Player] || zp_get_user_survivor(Player))
		return FMRES_IGNORED

	set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.001)
	return FMRES_HANDLED
}

public fw_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	if(!is_user_connected(attacker) || !is_user_alive(victim))
        return HAM_IGNORED

	if (get_user_weapon(attacker) == CSW_UMP45 && g_has_uganda[attacker])
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public fw_uganda_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, 41, 4)

	if(!is_user_alive(Player))
		return
	
	if (!g_has_uganda[Player] || (get_user_weapon(Player) != CSW_UMP45) || zp_get_user_zombie(Player))
		return;
	
	g_IsInPrimaryAttack = 1
	pev(Player,pev_punchangle, cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	static Float:push[3]
	pev(Player,pev_punchangle,push)
	xs_vec_sub(push,cl_pushangle[Player],push)
	
	xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_uganda),push)
	xs_vec_add(push,cl_pushangle[Player],push)
	set_pev(Player,pev_punchangle,push)
	
	if (!g_clip_ammo[Player])
		return
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_uganda) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED

	if (!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED

	//if(!g_has_uganda[invoker])
	//	return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public fw_uganda_PrimaryAttack_Post(Weapon)
{
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	if(!is_user_alive(Player)) 
		return;

	if(zp_get_user_zombie(Player) || !g_has_uganda[Player] || get_user_weapon(Player) != CSW_UMP45 || !g_clip_ammo[Player])
		return;
	
	static szClip, szAmmo, Float:push[3]
	get_user_weapon(Player, szClip, szAmmo)

	pev(Player,pev_punchangle,push)
	xs_vec_sub(push,cl_pushangle[Player],push)
	
	xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_uganda),push)
	xs_vec_add(push,cl_pushangle[Player],push)
	set_pev(Player,pev_punchangle,push)
	
	emit_sound(Player, CHAN_WEAPON, WPN_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	create_ring(Player)
	UTIL_PlayWeaponAnimation(Player, random_num(3, 5))
	//set_pdata_float(Player , m_flNextAttack, get_pcvar_float(cvar_fire_rate), PLAYER_LINUX_XTRA_OFF)
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if(!is_user_connected(attacker))
		return HAM_IGNORED

	if(zp_get_user_zombie(attacker) || zp_get_user_survivor(attacker) || victim == attacker)
		return HAM_IGNORED;

	if(get_user_weapon(attacker) == CSW_UMP45 && g_has_uganda[attacker] && !g_dmg[victim]) {
		g_dmg[victim] = 0
		return HAM_SUPERCEDE;	
	}	

	g_dmg[victim] = 0
	return HAM_IGNORED;
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
	
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, "ump45") && get_user_weapon(iAttacker) == CSW_UMP45)
	{
		if(g_has_uganda[iAttacker])
			set_msg_arg_string(4, "Uganda_Knuckles_Gun")
	}
		
	return PLUGIN_CONTINUE
}

public create_ring(id)
{
	static Float:origin[3], Float:angles[3], Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:gun_position[3], Float:player_origin[3], Float:player_view_offset[3];
	static Float:OriginX[3] , originplayerent[3] , Float:originend[3]
	get_user_origin(id,originplayerent,3)
	originend[0] = float(originplayerent[0])
	originend[1] = float(originplayerent[1])
	originend[2] = float(originplayerent[2])
	pev(id, pev_v_angle, angles);
	pev(id, pev_origin, OriginX);
	engfunc(EngFunc_MakeVectors, angles);

	global_get(glb_v_forward, v_forward);
	global_get(glb_v_right, v_right);
	global_get(glb_v_up, v_up);

	//m_pPlayer->GetGunPosition( ) = pev->origin + pev->view_ofs
	pev(id, pev_origin, player_origin);
	pev(id, pev_view_ofs, player_view_offset);
	xs_vec_add(player_origin, player_view_offset, gun_position);

	xs_vec_mul_scalar(v_forward, 13.0, v_forward);
	xs_vec_mul_scalar(v_right, 3.0, v_right);
	xs_vec_mul_scalar(v_up, -1.5, v_up);

	xs_vec_add(gun_position, v_forward, origin);
	xs_vec_add(origin, v_right, origin);
	xs_vec_add(origin, v_up, origin);

	static Float:StartOrigin[3], Float:Angle[3]
			
	StartOrigin[0] = origin[0];
	StartOrigin[1] = origin[1];
	StartOrigin[2] = origin[2];
			
	entity_get_vector(id, EV_VEC_v_angle, Angle)

	new ring = create_entity("info_target")
	entity_set_string(ring, EV_SZ_classname, RING_NAME)
	entity_set_model(ring, RING_MODEL)
	entity_set_origin(ring, StartOrigin)
	entity_set_vector(ring, EV_VEC_angles, Angle)
		
	static Float:MinBox[3], Float:MaxBox[3]
	MinBox = Float:{-1.0, -1.0, -1.0}
	MaxBox = Float:{1.0, 1.0, 1.0}

	entity_set_vector(ring, EV_VEC_mins, MinBox)
	entity_set_vector(ring, EV_VEC_maxs, MaxBox)
	
	entity_set_int(ring, EV_INT_solid, SOLID_TRIGGER)
	entity_set_int(ring, EV_INT_movetype, 5)

	entity_set_edict(ring, EV_ENT_owner , id) 
		
	static Float:vec[3]
	aim_at_origin(ring, originend ,vec)
	engfunc(EngFunc_MakeVectors, vec)
	global_get(glb_v_forward, vec)
	vec[0] *= float(get_pcvar_num(cvar_uganda_speed))
	vec[1] *= float(get_pcvar_num(cvar_uganda_speed))
	vec[2] *= float(get_pcvar_num(cvar_uganda_speed))
	set_pev(ring, pev_velocity, vec)

	entity_set_float(ring, EV_FL_nextthink, get_gametime() + get_pcvar_float(cvar_uganda_life)) 

}


stock fm_cs_get_current_weapon_ent(id)
{
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);
}


public uganda_ItemPostFrame(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	if (!is_user_connected(id))
		return HAM_IGNORED;

	if (!g_has_uganda[id])
		return HAM_IGNORED;

	if(get_user_weapon(id) != CSW_UMP45)
		return HAM_IGNORED

	static Float:flNextAttack, iBpAmmo, iClip, fInReload, j

	flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)

	iBpAmmo = cs_get_user_bpammo(id, CSW_UMP45);
	iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

	fInReload = get_pdata_int(weapon_entity, m_fInReload, WEAP_LINUX_XTRA_OFF) 

	if( fInReload && flNextAttack <= 0.0 )
	{
		j = min(get_pcvar_num(cvar_clip_uganda) - iClip, iBpAmmo)
	
		set_pdata_int(weapon_entity, m_iClip, iClip + j, WEAP_LINUX_XTRA_OFF)
		cs_set_user_bpammo(id, CSW_UMP45, iBpAmmo-j);
		
		set_pdata_int(weapon_entity, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
		fInReload = 0
	}

	return HAM_IGNORED;
}

public uganda_Reload(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	if (!is_user_connected(id))
		return HAM_IGNORED;

	if (!g_has_uganda[id])
		return HAM_IGNORED;

	if(get_user_weapon(id) != CSW_UMP45)
		return HAM_IGNORED

	g_uganda_TmpClip[id] = -1;

	static iBpAmmo, iClip
	iBpAmmo = cs_get_user_bpammo(id, CSW_UMP45);
	iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

	if (iBpAmmo <= 0)
		return HAM_SUPERCEDE;

	if (iClip >= get_pcvar_num(cvar_clip_uganda))
		return HAM_SUPERCEDE;

	g_uganda_TmpClip[id] = iClip;

	return HAM_IGNORED;
}

public uganda_Reload_Post(weapon_entity) {
	new id = pev(weapon_entity, pev_owner)
	if (!is_user_connected(id))
		return HAM_IGNORED;

	if (!g_has_uganda[id])
		return HAM_IGNORED;

	if (g_uganda_TmpClip[id] == -1)
		return HAM_IGNORED;

	if(get_user_weapon(id) != CSW_UMP45)
		return HAM_IGNORED

	set_pdata_int(weapon_entity, m_iClip, g_uganda_TmpClip[id], WEAP_LINUX_XTRA_OFF)
	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, RELOAD_TIME, WEAP_LINUX_XTRA_OFF)
	set_pdata_float(id, m_flNextAttack, RELOAD_TIME, PLAYER_LINUX_XTRA_OFF)
	set_pdata_int(weapon_entity, m_fInReload, 1, WEAP_LINUX_XTRA_OFF)
	UTIL_PlayWeaponAnimation(id, 1)

	return HAM_IGNORED;
}

public client_putinserver(id) reset_vars(id);
public zp_user_humanized_post(id) reset_vars(id);
public zp_user_infected_post(id) reset_vars(id);
public fw_PlayerSpawn_Post(id) reset_vars(id);

#if AMXX_VERSION_NUM < 183
public client_disconnect(id) reset_vars(id)
#else
public client_disconnected(id) reset_vars(id)
#endif

public reset_vars(id)
{
	g_has_uganda[id] = false
	g_dmg[id] = 0
}

public remove_ring(ent) if(is_valid_ent(ent)) remove_entity(ent);

stock drop_weapons(id, dropwhat)
{
     static weapons[32], num, i, weaponid
     num = 0
     get_user_weapons(id, weapons, num)
     
     for (i = 0; i < num; i++)
     {
          weaponid = weapons[i]
          
          if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
          {
               static wname[32]
               get_weaponname(weaponid, wname, sizeof wname - 1)
               engclient_cmd(id, "drop", wname)
          }
     }
}

stock make_blood(const Float:vTraceEnd[3], Float:Damage, hitEnt) {
	new bloodColor = ExecuteHam(Ham_BloodColor, hitEnt);
	if (bloodColor == -1 || !zp_get_user_zombie(hitEnt) || !is_user_alive(hitEnt))
		return;

	new amount = floatround(Damage);

	amount *= 2; //according to HLSDK

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BLOODSPRITE);
	write_coord(floatround(vTraceEnd[0]));
	write_coord(floatround(vTraceEnd[1]));
	write_coord(floatround(vTraceEnd[2]));
	write_short(m_iBlood[1]);
	write_short(m_iBlood[0]);
	write_byte(bloodColor);
	write_byte(min(max(3, amount/10), 16));
	message_end();
}

stock aim_at_origin(id, Float:target[3], Float:angles[3])
{
	static Float:vec[3]
	pev(id,pev_origin,vec)
	vec[0] = target[0] - vec[0]
	vec[1] = target[1] - vec[1]
	vec[2] = target[2] - vec[2]
	engfunc(EngFunc_VecToAngles,vec,angles)
	angles[0] *= -1.0, angles[2] = 0.0
}
stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(0)
	message_end()
}
