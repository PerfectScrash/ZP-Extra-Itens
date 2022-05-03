/*============================================
	-> [ZPSp] Extra Item: Golden guitar <-

* Description:
	- Give a player a Weapon Golden Guitar

* Requeriments:
	- Zombie Plague Special 4.5 or higher

* Cvars:
	zp_golden_guitar_dmg "1.5"		// Weapon Damage Multipler
	zp_golden_guitar_recoil "0.1"	// Weapon Recoil
	zp_golden_guitar_clip "40"		// Weapon Clip Ammo
	zp_golden_guitar_spd "1.0"		// Weapon Speed Shoot
	zp_golden_guitar_ammo "180"		// Weapon Ammo
	zp_golden_guitar_bullets "1"	// Gold tracer on bullets (0 - Disable | 1 - Enable)

* Credits:
	- Unknow Author: For Rock Guitar .sma
	- ShaunCraft15: Custom bullet tracer
	- Perfect Scrash: Otimization and for ZPSp 4.5 version

* Changelog:
	- 1.0:
		- First Version

============================================*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <zombie_plague_special>

/*============================================
-> Plugin Configuration
============================================*/
// Extra item configuration
new const Item_Name[] = "Golden Guitar"
new const Item_Price = 100

// Weapon model
new Wpn_V_Model[] = "models/zombie_plague/v_golden_guitar.mdl"
new Wpn_P_Model[] = "models/zombie_plague/p_golden_guitar.mdl"
new Wpn_W_Model[] = "models/zombie_plague/w_golden_guitar.mdl"

// Weapon Sound
new const Weapon_Sounds[][] = { 
	"weapons/rguitar.wav", // Fire sound
	"weapons/zoom.wav", // Zoom Sound
	"weapons/gt_clipout.wav", 
	"weapons/gt_draw.wav",		// Model sounds
	"weapons/gt_clipin.wav",
	"weapons/gt_clipon.wav"
 }

/*============================================
-> Defines/Variables/Consts
============================================*/
#define ENG_NULLENT		-1
#define Pev_WpnKey pev_impulse
#define m_fKnown 44
#define m_flNextPrimaryAttack 46
#define m_flTimeWeaponIdle 48
#define m_iClip 51
#define m_fInReload 54
#define m_flNextAttack 83
#define Wpn_Reload_Time 2.5
#define Weapon_Key 1231982

const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4

new cvar_dmg_wpn, cvar_recoil_wpn, g_itemid, cvar_clip_wpn, cvar_spd_wpn, cvar_wpn_ammo, cvar_goldbullets, m_spriteTexture
new g_have_wpn[33], Float:cl_pushangle[33][3], g_hasZoom[33], g_event_wpn, g_IsInPrimaryAttack, g_clip_ammo[33], g_wpn_TmpClip[33]
new const TracePreEntities[][] = { "func_breakable", "func_wall", "func_door", "func_door_rotating", "func_plat", "func_rotating", "player", "worldspawn" }

/*============================================
-> Plugin registeration
============================================*/
public plugin_init() {
	// Plugin registeration
	register_plugin("[ZPSp] Extra: Golden Guitar", "1.0", "Unknow Author | P. Scrash")
	
	// Game Events
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")

	// Fakemeta Events
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")

	// Ham Events
	RegisterHam(Ham_Item_AddToPlayer, "weapon_galil", "fw_Wpn_AddtoPlayer")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_galil", "fw_Wpn_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_galil", "fw_Wpn_PrimaryAttack_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_PostFrame, "weapon_galil", "fw_ItemPostFrame");
	RegisterHam(Ham_Weapon_Reload, "weapon_galil", "fw_Reload");
	RegisterHam(Ham_Weapon_Reload, "weapon_galil", "fw_Reload_Post", 1);

	for(new i = 0; i < sizeof TracePreEntities; i++)
		RegisterHam(Ham_TraceAttack, TracePreEntities[i], "fw_TraceAttackPre");

	// Cvars
	cvar_dmg_wpn = register_cvar("zp_golden_guitar_dmg", "1.5")
	cvar_recoil_wpn = register_cvar("zp_golden_guitar_recoil", "0.1")
	cvar_clip_wpn = register_cvar("zp_golden_guitar_clip", "40")
	cvar_spd_wpn = register_cvar("zp_golden_guitar_spd", "1.0")
	cvar_wpn_ammo = register_cvar("zp_golden_guitar_ammo", "180")
	cvar_goldbullets = register_cvar("zp_golden_guitar_bullets", "1")

	// Extra Item registeration
	g_itemid = zp_register_extra_item(Item_Name, Item_Price, ZP_TEAM_HUMAN)
}
/*============================================
-> Plugin precache
============================================*/
public plugin_precache() {
	m_spriteTexture = precache_model("sprites/dot.spr")
	precache_model(Wpn_V_Model)
	precache_model(Wpn_P_Model)
	precache_model(Wpn_W_Model)
	for(new i = 0; i < sizeof Weapon_Sounds; i++)
		precache_sound(Weapon_Sounds[i])

	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public fwPrecacheEvent_Post(type, const name[]) {
	if(equal("events/galil.sc", name)) {
		g_event_wpn = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

/*============================================
-> Reset variables
============================================*/
public client_putinserver(id) g_have_wpn[id] = false;
public zp_user_infected_post(id) g_have_wpn[id] = false;
public zp_user_humanized_post(id) g_have_wpn[id] = false;
public zp_player_spawn_post(id) g_have_wpn[id] = false;

/*============================================
-> Extra Item functions
============================================*/
public zp_extra_item_selected_pre(player, itemid) {
	if(itemid != g_itemid) 
		return PLUGIN_CONTINUE;

	if(g_have_wpn[player]) {
		zp_menu_textadd("\r[Alterady Have]")
		return ZP_PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;	
}
public zp_extra_item_selected(id, itemid) {
	if(itemid != g_itemid)
		return PLUGIN_CONTINUE;
	
	if(g_have_wpn[id]) {
		client_print_color(id, print_team_grey, "^4[ZP]^3 You alterady have a ^1Golden Guitar")
		return ZP_PLUGIN_HANDLED;
	}
	zp_drop_weapons(id, WPN_PRIMARY)
	g_have_wpn[id] = true;
	zp_give_item(id, "weapon_galil");
	UTIL_PlayWeaponAnimation(id, 2);
	cs_set_user_bpammo(id, CSW_GALIL, get_pcvar_num(cvar_wpn_ammo));
	fm_cs_set_user_ammo(id, "weapon_galil", get_pcvar_num(cvar_clip_wpn));
	client_print_color(id, print_team_grey, "^4[ZP]^3 You purcharsed a ^1Golden Guitar^3 with sucess !!")
	return PLUGIN_CONTINUE
}

/*============================================
-> Weapon model
============================================*/
public zp_fw_deploy_weapon(id, wpnid) {
	if(wpnid != CSW_GALIL || !is_user_alive(id))
		return;

	if(zp_get_user_zombie(id) || zp_get_human_special_class(id) || !g_have_wpn[id])
		return;

	set_pev(id, pev_viewmodel2, Wpn_V_Model)
	set_pev(id, pev_weaponmodel2, Wpn_P_Model)
}

// W_ model
public fw_SetModel(entity, model[]) {
	if(!pev_valid(entity))
		return FMRES_IGNORED;

	static szClassName[33]
	pev(entity, pev_classname, szClassName, charsmax(szClassName))

	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED;

	static iOwner
	iOwner = pev(entity, pev_owner)

	if(!equal(model, "models/w_galil.mdl"))
		return FMRES_IGNORED;
	
	static iStoredWpnID
	iStoredWpnID = fm_find_ent_by_owner(ENG_NULLENT, "weapon_galil", entity)

	if(!pev_valid(iStoredWpnID))
		return FMRES_IGNORED;

	if(g_have_wpn[iOwner]) {
		set_pev(iStoredWpnID, Pev_WpnKey, Weapon_Key)
		g_have_wpn[iOwner] = false
		engfunc(EngFunc_SetModel, entity, Wpn_W_Model)
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

/*============================================
-> Weapon functions
============================================*/
public fw_TraceAttackPre(iVictim, iAttacker, Float:fDamage, Float:fDeriction[3], iTraceHandle, iBitDamage) {
	if(!is_user_alive(iAttacker) || !get_pcvar_num(cvar_goldbullets))
		return;

	if(get_user_weapon(iAttacker) != CSW_GALIL || !g_have_wpn[iAttacker])
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
	write_short(m_spriteTexture)
	write_byte(1) // framestart
	write_byte(5) // framerate
	write_byte(2) // life
	write_byte(10) // width
	write_byte(0) // noise
	write_byte(255)     // r, g, b
	write_byte(215)       // r, g, b
	write_byte(0)       // r, g, b
	write_byte(200) // brightness
	write_byte(150) // speed
	message_end()
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle) {
	if(!is_user_alive(Player))
		return FMRES_HANDLED

	if(get_user_weapon(Player) != CSW_GALIL || !g_have_wpn[Player] || zp_get_user_zombie(Player))
		return FMRES_IGNORED;

	set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.001)
	return FMRES_HANDLED
}


public fw_Wpn_AddtoPlayer(Wpn, id) {
	if(!pev_valid(Wpn) || !is_user_connected(id))
		return HAM_IGNORED;

	if(pev(Wpn, Pev_WpnKey) == Weapon_Key) {
		g_have_wpn[id] = true
		set_pev(Wpn, Pev_WpnKey, 0)
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public fw_Wpn_PrimaryAttack(Weapon) {
	new Player = fm_cs_get_weapon_ent_owner(Weapon)

	if(!g_have_wpn[Player])
		return;

	g_IsInPrimaryAttack = 1
	pev(Player, pev_punchangle, cl_pushangle[Player])

	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2) {
	if((eventid != g_event_wpn) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
	if(!(1 <= invoker <= MaxClients))
		return FMRES_IGNORED

	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public fw_Wpn_PrimaryAttack_Post(Weapon) {
	static Player;
	Player = fm_cs_get_weapon_ent_owner(Weapon)
	g_IsInPrimaryAttack = 0;

	if(!g_have_wpn[Player])
		return;
	
	static Float:push[3]
	pev(Player, pev_punchangle, push)
	xs_vec_sub(push, cl_pushangle[Player], push)

	xs_vec_mul_scalar(push, get_pcvar_float(cvar_recoil_wpn), push)
	xs_vec_add(push, cl_pushangle[Player], push)
	set_pev(Player, pev_punchangle, push)

	if(!g_clip_ammo[Player])
		return

	emit_sound(Player, CHAN_WEAPON, Weapon_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	UTIL_PlayWeaponAnimation(Player, random_num(3, 4))

	static Float:Delay, Float:iSpeed
	iSpeed = get_pcvar_float(cvar_spd_wpn)
	Delay = get_pdata_float(Weapon, m_flNextPrimaryAttack, OFFSET_LINUX_WEAPONS) * iSpeed
	if(Delay > 0.0)
		set_pdata_float(Weapon, m_flNextPrimaryAttack, Delay, OFFSET_LINUX_WEAPONS)
	
}
public fw_TakeDamage(victim, inflictor, attacker, Float:damage) {
	if(victim == attacker || !is_user_connected(attacker) || !is_user_connected(victim))
		return HAM_IGNORED;
	
	if(get_user_weapon(attacker) != CSW_GALIL || zp_get_user_zombie(attacker) || !g_have_wpn[attacker])
		return HAM_IGNORED

	SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg_wpn))
	return HAM_IGNORED
}

public message_DeathMsg(msg_id, msg_dest, id) {
	static szTruncatedWeapon[33], iAttacker

	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))

	iAttacker = get_msg_arg_int(1)
	if(!is_user_connected(iAttacker))
		return PLUGIN_CONTINUE

	if(!g_have_wpn[iAttacker] || get_user_weapon(iAttacker) != CSW_GALIL || !equal(szTruncatedWeapon, "galil"))
		return PLUGIN_CONTINUE

	set_msg_arg_string(4, "Golden-Guitar")
	return PLUGIN_CONTINUE
}

public fw_ItemPostFrame(WpnEnt) {
	static id;
	id = fm_cs_get_weapon_ent_owner(WpnEnt)
	if(!is_user_connected(id))
		return HAM_IGNORED;

	if(!g_have_wpn[id])
		return HAM_IGNORED;

	static iClipExtra, Float:flNextAttack, iBpAmmo, iClip, fInReload, j
	iClipExtra = get_pcvar_num(cvar_clip_wpn)
	flNextAttack = get_pdata_float(id, m_flNextAttack, OFFSET_LINUX)
	iBpAmmo = cs_get_user_bpammo(id, CSW_GALIL);
	iClip = get_pdata_int(WpnEnt, m_iClip, OFFSET_LINUX_WEAPONS)
	fInReload = get_pdata_int(WpnEnt, m_fInReload, OFFSET_LINUX_WEAPONS)

	if(fInReload && flNextAttack <= 0.0) {
		j = min(iClipExtra - iClip, iBpAmmo)
		set_pdata_int(WpnEnt, m_iClip, iClip + j, OFFSET_LINUX_WEAPONS)
		cs_set_user_bpammo(id, CSW_GALIL, iBpAmmo-j);
		set_pdata_int(WpnEnt, m_fInReload, 0, OFFSET_LINUX_WEAPONS)
		fInReload = 0
	}
	return HAM_IGNORED;
}

public fw_Reload(WpnEnt) {
	static id;
	id = fm_cs_get_weapon_ent_owner(WpnEnt)
	if(!is_user_connected(id))
		return HAM_IGNORED;

	if(!g_have_wpn[id])
		return HAM_IGNORED;

	static iClipExtra, iBpAmmo, iClip
	iClipExtra = get_pcvar_num(cvar_clip_wpn)
	g_wpn_TmpClip[id] = -1;
	iBpAmmo = cs_get_user_bpammo(id, CSW_GALIL);
	iClip = get_pdata_int(WpnEnt, m_iClip, OFFSET_LINUX_WEAPONS)

	if(iBpAmmo <= 0 || iClip >= iClipExtra)
		return HAM_SUPERCEDE;

	g_wpn_TmpClip[id] = iClip;
	return HAM_IGNORED;
}

public fw_Reload_Post(WpnEnt) {
	static id;
	id = fm_cs_get_weapon_ent_owner(WpnEnt)
	if(!is_user_connected(id))
		return HAM_IGNORED;

	if(!g_have_wpn[id] || g_wpn_TmpClip[id] == -1)
		return HAM_IGNORED;

	static Float:iReloadTime
	iReloadTime = Wpn_Reload_Time
	set_pdata_int(WpnEnt, m_iClip, g_wpn_TmpClip[id], OFFSET_LINUX_WEAPONS)
	set_pdata_float(WpnEnt, m_flTimeWeaponIdle, iReloadTime, OFFSET_LINUX_WEAPONS)
	set_pdata_float(id, m_flNextAttack, iReloadTime, OFFSET_LINUX)
	set_pdata_int(WpnEnt, m_fInReload, 1, OFFSET_LINUX_WEAPONS)

	UTIL_PlayWeaponAnimation(id, 1)

	return HAM_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed) {
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE

	static Button, OldButton;
	Button = pev(id, pev_button)
	OldButton = pev(id, pev_oldbuttons)

	if((Button & IN_ATTACK2) && !(OldButton & IN_ATTACK2) && g_have_wpn[id]) {
		static szClip, szAmmo, szWeapID
		szWeapID = get_user_weapon(id, szClip, szAmmo)
		if(szWeapID != CSW_GALIL)
			return PLUGIN_CONTINUE

		if(g_hasZoom[id]) {
			g_hasZoom[id] = false
			cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
		}
		else {
			g_hasZoom[id] = true
			cs_set_user_zoom(id, CS_SET_AUGSG552_ZOOM, 1)
			emit_sound(id, CHAN_ITEM, Weapon_Sounds[1], 0.20, 2.40, 0, 100)
		}
	}

	if(g_hasZoom[id] && (Button & IN_RELOAD)) {
		g_hasZoom[id] = false
		cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
	}
	return PLUGIN_HANDLED
}

/*============================================
-> Stocks
============================================*/
stock fm_cs_get_current_weapon_ent(id)
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);

stock fm_cs_get_weapon_ent_owner(ent)
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);

stock UTIL_PlayWeaponAnimation(const Player, const Sequence) {
	set_pev(Player, pev_weaponanim, Sequence)

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}
stock fm_find_ent_by_owner(index, const classname[], owner, jghgtype = 0) {
	new strtype[11] = "classname", ent = index;
	switch (jghgtype) {
		case 1: strtype = "target";
		case 2: strtype = "targetname";
	}

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, strtype, classname)) && pev(ent, pev_owner) != owner) {}

	return ent;
}

stock fm_cs_set_user_ammo(id, wpn_name[], quantity) {
	if(!is_user_connected(id))
		return 0;

	static iWep2
	iWep2 = fm_find_ent_by_owner(ENG_NULLENT, wpn_name, id)
	if(iWep2 > 0 && pev_valid(iWep2)) 
		cs_set_weapon_ammo(iWep2, quantity)

	//set_pdata_int(WpnEnt, m_iClip, quantity, OFFSET_LINUX_WEAPONS)
	
	return 1;

}