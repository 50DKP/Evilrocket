/*
CHANGELOG:
----------
v1.3.1 (March 17, 2014 A.D.):  Some minor fixes (Wliu).
v1.3.0 (February 2, 2014 A.D.):  Rewrote !rocketme message handling (Wliu).
v1.2.2 (August 15, 2013 A.D.):  Fixed compile errors/formatting (Wliu).
v1.2.1 (August 14, 2013 A.D.):  Optimized array code and made #pragma semicolon 1 (Wliu).
v1.2.0:  Fixed numerous exploits (Chris).
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <adminmenu>
#undef REQUIRE_PLUGIN

new Handle:adminMenu=INVALID_HANDLE;

new Handle:cvarRocketMe=INVALID_HANDLE;

new gametype=0;
new explosion;

new rocket[MAXPLAYERS+1];
new String:gameName[64];

new bool:bonusRound=false;
new bool:canMessage[MAXPLAYERS+1]={true, ...};

#define PLUGIN_VERSION "1.3.1"

public Plugin:myinfo=
{
	name="Evil Admin - Rocket",
	author="<eVa>Dog, 50DKP",
	description="Make a rocket with a player",
	version=PLUGIN_VERSION,
	url="http://www.theville.org"
};

public OnPluginStart()
{
	CreateConVar("sm_evilrocket_version", PLUGIN_VERSION, " Evil Rocket Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvarRocketMe=CreateConVar("sm_rocketme_enabled", "0", " Allow players to suicide as a rocket", FCVAR_PLUGIN);

	RegAdminCmd("sm_evilrocket", Command_EvilRocket, ADMFLAG_SLAY, "sm_evilrocket <#userid|name>");
	RegConsoleCmd("sm_rocketme", Command_RocketMe, "A fun way to suicide :3");

	LoadTranslations("common.phrases");

	GetGameFolderName(gameName, sizeof(gameName));
	if(StrEqual(gameName, "tf"))
	{
		HookEvent("teamplay_round_win", RoundWinEvent);
		HookEvent("teamplay_round_active", RoundStartEvent);
	}
	else if(StrEqual(gameName, "dod"))
	{
		HookEvent("dod_round_win", RoundWinEvent);
		HookEvent("dod_round_active", RoundStartEvent);
	}

	new Handle:topmenu;
	if(LibraryExists("adminmenu") && ((topmenu=GetAdminTopMenu())!=INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public Action:RoundWinEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	bonusRound=true;
}

public Action:RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	bonusRound=false;
}

public OnEventShutdown()
{
	if(StrEqual(gameName, "tf"))
	{
		UnhookEvent("teamplay_round_win", RoundWinEvent);
		UnhookEvent("teamplay_round_active", RoundStartEvent);
	}
	else if(StrEqual(gameName, "dod"))
	{
		UnhookEvent("dod_round_win", RoundWinEvent);
		UnhookEvent("dod_round_active", RoundStartEvent);
	}
}

public OnMapStart()
{
	if(StrEqual(gameName, "tf"))
	{
		gametype=1;
	}
	else if(StrEqual(gameName, "dod"))
	{
		gametype=2;
	}
	else 
	{
		gametype=0;
	}

	explosion=PrecacheModel("sprites/sprite_fire01.vmt");

	PrecacheSound("ambient/explosions/exp2.wav", true);
	PrecacheSound("npc/env_headcrabcanister/launch.wav", true);
	PrecacheSound("weapons/rpg/rocketfire1.wav", true);
}

public Action:Command_EvilRocket(client, args)
{
	decl String:target[65];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	new bool:tn_is_ml;

	if(args<1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_evilrocket <#userid|name>");
		return Plugin_Handled;
	}
	GetCmdArg(1, target, sizeof(target));

	if((target_count=ProcessTargetString(target, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml))<=0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(new client2=0; client2<target_count; client2++)
	{
		if(IsClientInGame(target_list[client2]) && IsPlayerAlive(target_list[client2]))
		{
			PerformEvilRocket(client2, target_list[client2]);
		}
	}
	return Plugin_Handled;
}

PerformEvilRocket(client, target)
{
	if(rocket[target]==0)
	{
		if(client>=0)
		{
			LogAction(client, target, "\"%L\" sent \"%L\" into space", client, target);
			ShowActivity(client, "launched %N into space", target);
			PrintToChatAll("[SM] %N was launched into space!", target);

			if(gametype==1)
			{
				AttachParticle(target, "rockettrail_!");
			}
			else if(gametype==2)
			{
				AttachParticle(target, "rockettrail");
			}
			else
			{
				AttachFlame(target);
			}
			EmitSoundToAll("weapons/rpg/rocketfire1.wav", target, _, _, _, 0.8);
			CreateTimer(2.0, Launch, target);
			CreateTimer(3.5, Detonate, target);
		}
		else if(client==-2)
		{
			if(gametype==1)
			{
				AttachParticle(target, "rockettrail_!");
			}
			else if(gametype==2)
			{
				AttachParticle(target, "rockettrail");
			}
			else
			{
				AttachFlame(target);
			}
			EmitSoundToAll("weapons/rpg/rocketfire1.wav", target, _, _, _, 0.8);
			CreateTimer(2.0, Launch, target);
			CreateTimer(3.5, Detonate, target);
		}
	}
}

public Action:Launch(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		new Float:velocity[]={0.0, 0.0, 800.0};
		EmitSoundToAll("ambient/explosions/exp2.wav", client, _, _, _, 1.0);
		EmitSoundToAll("npc/env_headcrabcanister/launch.wav", client, _, _, _, 1.0);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		SetEntityGravity(client, 0.1);
	}
	return Plugin_Handled;
}

public Action:Detonate(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		new Float:player[3];
		GetClientAbsOrigin(client, player);
		if(gametype==1)
		{
			DeleteParticle(rocket[client]);
			rocket[client]=0;
			if(bonusRound)
			{
				new Float:ClientOrigin[3];
				GetClientAbsOrigin(client, ClientOrigin);
				if(IsPlayerAlive(client))
				{
					new entity=CreateEntityByName("env_explosion");
					DispatchKeyValue(entity, "iMagnitude", "2000");
					DispatchKeyValue(entity, "iRadiusOverride", "15");
					DispatchSpawn(entity);
					TeleportEntity(entity, ClientOrigin, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(entity, "Explode");
					CreateTimer(3.0, KillExplosion, entity);
				}
			}
			else
			{
				if(IsPlayerAlive(client))
				{
					FakeClientCommand(client, "Explode");
				}
			}
		}
		else if(gametype==2)
		{
			DeleteParticle(rocket[client]);
			rocket[client]=0;
			if(IsPlayerAlive(client))
			{
				FakeClientCommand(client, "Explode");
			}
		}
		else if(IsPlayerAlive(client))
		{
			TE_SetupExplosion(player, explosion, 10.0, 1, 0, 600, 5000);
			TE_SendToAll();
			rocket[client]=0;
			ForcePlayerSuicide(client);
		}
		ForcePlayerSuicide(client);
		SetEntityGravity(client, 1.0);
	}
	return Plugin_Handled;
}

public Action:KillExplosion(Handle:timer, any:entity)
{
	if(IsValidEntity(entity))
	{
		decl String:classname[128];
		GetEdictClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "env_explosion", false))
		{
			RemoveEdict(entity);
		}
	}
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name, "adminmenu")) 
	{
		adminMenu=INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	if(topmenu==adminMenu)
	{
		return;
	}
	adminMenu=topmenu;
	new TopMenuObject:player_commands=FindTopMenuCategory(adminMenu, ADMINMENU_PLAYERCOMMANDS);

	if(player_commands!=INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(adminMenu, "sm_evilrocket", TopMenuObject_Item, AdminMenu_rocket, player_commands, "sm_evilrocket", ADMFLAG_SLAY);
	}
}

public AdminMenu_rocket(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action==TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Evil Rocket");
	}
	else if(action==TopMenuAction_SelectOption)
	{
		DisplayPlayerMenu(param);
	}
}

DisplayPlayerMenu(client)
{
	new Handle:menu=CreateMenu(MenuHandler_Players);
	decl String:title[100];
	Format(title, sizeof(title), "Choose Player:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	AddTargetsToMenu(menu, client, true, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Players(Handle:menu, MenuAction:action, client, option)
{
	if(action==MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if(action==MenuAction_Cancel)
	{
		if(option==MenuCancel_ExitBack && adminMenu!=INVALID_HANDLE)
		{
			DisplayTopMenu(adminMenu, client, TopMenuPosition_LastCategory);
		}
	}
	else if(action==MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;

		GetMenuItem(menu, option, info, sizeof(info));
		userid=StringToInt(info);
		if((target=GetClientOfUserId(userid))==0)
		{
			PrintToChat(client, "[SM] %s", "Player no longer available");
		}
		else if(!CanUserTarget(client, target))
		{
			PrintToChat(client, "[SM] %s", "Unable to target");
		}
		else
		{
			PerformEvilRocket(client, target);
		}

		if(IsClientInGame(client) && !IsClientInKickQueue(client))
		{
			DisplayPlayerMenu(client);
		}
	}
}

AttachParticle(entity, String:particleType[])
{
	new particle=CreateEntityByName("info_particle_system");
	new String:targetName[128], String:particleName[128];
	if(IsValidEdict(particle))
	{
		new Float:position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
		if(gametype==1)
		{
			position[2]+=10;
			TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		}
		else if(gametype==2)
		{
			position[2]+=50;
			TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		}

		Format(targetName, sizeof(targetName), "target%i", entity);
		DispatchKeyValue(entity, "targetname", targetName);

		Format(particleName, sizeof(particleName), "particle%i", entity);
		DispatchKeyValue(particle, "targetname", particleName);

		DispatchKeyValue(particle, "parentname", targetName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);

		SetVariantString(targetName);
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);

		if(gametype==1)
		{
			SetVariantString("flag");
			AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
		}
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		rocket[entity]=particle;
	}
}

DeleteParticle(any:particle)
{
	if(IsValidEntity(particle))
	{
		new String:classname[256];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}
}

AttachFlame(entity)
{
	new String:flameName[128];
	Format(flameName, sizeof(flameName), "RocketFlame%i", entity);

	new String:targetName[128];
	new flame=CreateEntityByName("env_steam");
	if(IsValidEdict(flame))
	{
		new Float:position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
		position[2]+=30;
		new Float:angles[]={90.0, 0.0, 0.0};

		Format(targetName, sizeof(targetName), "target%i", entity);
		DispatchKeyValue(entity, "targetname", targetName);

		DispatchKeyValue(flame, "targetname", flameName);
		DispatchKeyValue(flame, "parentname", targetName);
		DispatchKeyValue(flame, "SpawnFlags", "1");
		DispatchKeyValue(flame, "Type", "0");
		DispatchKeyValue(flame, "InitialState", "1");
		DispatchKeyValue(flame, "Spreadspeed", "10");
		DispatchKeyValue(flame, "Speed", "800");
		DispatchKeyValue(flame, "Startsize", "10");
		DispatchKeyValue(flame, "EndSize", "250");
		DispatchKeyValue(flame, "Rate", "15");
		DispatchKeyValue(flame, "JetLength", "400");
		DispatchKeyValue(flame, "RenderColor", "180 71 8");
		DispatchKeyValue(flame, "RenderAmt", "180");
		DispatchSpawn(flame);
		TeleportEntity(flame, position, angles, NULL_VECTOR);
		SetVariantString(targetName);
		AcceptEntityInput(flame, "SetParent", flame, flame, 0);
		CreateTimer(3.0, DeleteFlame, flame);
		rocket[entity]=flame;
	}
}

public Action:DeleteFlame(Handle:timer, any:entity)
{
	if(IsValidEntity(entity))
	{
		decl String:classname[128];
		GetEdictClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "env_steam", false))
		{
			RemoveEdict(entity);
		}
	}
}

public Action:Command_RocketMe(client, args)
{
	new flags=GetUserFlagBits(client);
	if(flags & ADMFLAG_ROOT || flags & ADMFLAG_VOTE)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			PerformEvilRocket(-2, client);
			CreateTimer(3.4, MessageUs, client);
		}
	}
	else if(GetConVarInt(cvarRocketMe))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			PerformEvilRocket(-2, client);
			CreateTimer(3.4, MessageUs, client);
		}
	}
	else
	{
		PrintToChat(client, "[SM] RocketMe is not enabled");
	}
	return Plugin_Handled;
}

public Action:MessageUs(Handle:timer, any:client)
{
	if(canMessage[client] && IsPlayerAlive(client))
	{
		PrintToChatAll("[SM] %N died in a rocket-related accident", client);
		canMessage[client]=false;
		CreateTimer(3.0, MakeCanMessage, client);
	}

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "[SM] You have to be alive to use RocketMe!");
	}
}

public Action:MakeCanMessage(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		canMessage[client]=true;
	}
}

public OnClientDisconnect(client)
{
	if(IsClientInGame(client))
	{
		canMessage[client]=true;
	}
}