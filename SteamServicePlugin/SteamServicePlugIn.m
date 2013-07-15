//
//  SteamServicePlugIn.m
//  SteamServicePlugin
//
//  Created by Yaakov on 3/03/13.
//  Copyright (c) 2013 Coding Range. All rights reserved.
//

#import "SteamServicePlugIn.h"
#import <SKSteamKit/SKSteamClient.h>
#import <SKSteamKit/SKSteamUser.h>
#import <SKSteamKit/SKSteamFriends.h>
#import <CRBoilerplate/CRBoilerplate.h>
#import <SKSteamKit/SKNSNotificationExtensions.h>
#import <SKSteamKit/SKSteamChatMessageInfo.h>
#import <SKSteamKit/SKSteamFriend.h>
#import <SKSteamKit/SKSteamPersonaStateInfo.h>

@implementation SteamServicePlugIn
{
	id<IMServiceApplication> _serviceApplication;
	SKSteamClient * _client;
	NSDictionary * _loginDetails;
}

- (id) initWithServiceApplication:(id<IMServiceApplication>)serviceApplication
{
	self = [super init];
	if (self)
	{
		_serviceApplication = serviceApplication;
		_client = [[SKSteamClient alloc] init];
		
		NSNotificationCenter * notificationCenter = [NSNotificationCenter defaultCenter];
		
		[notificationCenter addObserver:self selector:@selector(steamClientDidDisconect:) name:SKSteamClientDisconnectedNotification object:_client];
		[notificationCenter addObserver:self selector:@selector(steamClientDidRecieveFriendMessage:) name:SKSteamChatMessageInfoNotification object:_client];
		[notificationCenter addObserver:self selector:@selector(steamClientDidRecievePersonaState:) name:SKSteamPersonaStateInfoNotification object:_client];
		[notificationCenter addObserver:self selector:@selector(steamClientDidRecieveFriendsList:) name:SKSteamFriendsListNotification object:_client];
	}
	return self;
}

- (oneway void) updateAccountSettings:(NSDictionary *)accountSettings
{
	_loginDetails = @{SKLogonDetailUsername: accountSettings[IMAccountSettingLoginHandle], SKLogonDetailPassword:accountSettings[IMAccountSettingPassword], SKLogonDetailRememberMe: @NO};
}

- (oneway void) login
{
	NSLog(@"Connecting...");
	
	[[[_client connect] addSuccessHandler:^(id data) {
		SKSteamUser * user = [_client steamUser];
		NSLog(@"Connected to Steam. Logging in...");
		[[[user logOnWithDetails:_loginDetails] addSuccessHandler:^(id data) {
			NSLog(@"Logged in to Steam: %@", data);
			[_serviceApplication plugInDidLogIn];
		}] addFailureHandler:^(NSError *error) {
			NSLog(@"Failed to log in to Steam: %@", error);
			[_serviceApplication plugInDidFailToAuthenticate];
		}];
	}] addFailureHandler:^(NSError *error) {
		NSLog(@"Failed to connect to Steam");
		[_serviceApplication plugInDidLogOutWithError:error reconnect:YES];
	}];
	
}

- (oneway void) logout
{
	[_client disconnect];
}

- (oneway void) userDidStartTypingToHandle:(NSString *)handle
{
	SKSteamFriends * friends = [_client steamFriends];
	SKSteamFriend * friend = [friends friendWithSteamID:[self steamIDOfFriendWithHandle:handle]];
	[friends sendChatMessageToFriend:friend type:EChatEntryTypeTyping text:nil];
}

- (oneway void) userDidStopTypingToHandle:(NSString *)handle
{
	NSLog(@"stopped typing to %@", handle);
}

- (oneway void) sendMessage:(IMServicePlugInMessage *)message toHandle:(NSString *)handle
{
	SKSteamFriends * friends = [_client steamFriends];
	SKSteamFriend * friend = [friends friendWithSteamID:[self steamIDOfFriendWithHandle:handle]];
	[friends sendChatMessageToFriend:friend type:EChatEntryTypeChatMsg text:[[message content] string]];
	
	[(id<IMServiceApplicationInstantMessagingSupport>)_serviceApplication plugInDidSendMessage:message toHandle:handle error:nil];
}

- (uint64_t) steamIDOfFriendWithHandle:(NSString *)handle
{
	return strtoull([handle UTF8String], NULL, 10);
}

- (void) steamClientDidDisconect:(NSNotification *)notification
{
	NSLog(@"Error: %@,", [notification steamInfo]);
	[_serviceApplication plugInDidLogOutWithError:[notification steamInfo] reconnect:YES];
}

- (oneway void) updateSessionProperties:(NSDictionary *)properties
{
	NSLog(@"New session properties: %@", properties);
	
	NSNumber * availability = properties[IMSessionPropertyAvailability];
	IMSessionAvailability sessionAvailability = [availability integerValue];
	
	SKSteamFriends * friends = [_client steamFriends];
	EPersonaState newState;
	
	switch (sessionAvailability)
	{
		case IMSessionAvailabilityAvailable:
			newState = EPersonaStateOnline;
			break;
			
		case IMSessionAvailabilityAway:
			newState = EPersonaStateAway;
			break;
			
		default:
			newState = EPersonaStateOnline;
			break;
	}
	
	[friends setPersonaState:newState];
}

- (void) steamClientDidRecieveFriendMessage:(NSNotification *)notification
{
	SKSteamChatMessageInfo * info = [notification steamInfo];
	
	if ([info steamFriendFrom].steamId != _client.steamID)
	{
		NSString * handle = [self handleForSteamFriend:[info steamFriendFrom]];

		switch (info.chatEntryType)
		{
			case EChatEntryTypeTyping:
				[(id<IMServiceApplicationInstantMessagingSupport>)_serviceApplication handleDidStartTyping:handle];
				break;
				
			case EChatEntryTypeChatMsg:
			{
				NSAttributedString * text = [[NSAttributedString alloc] initWithString:info.message];
				IMServicePlugInMessage * message = [[IMServicePlugInMessage alloc] initWithContent:text];
				[(id<IMServiceApplicationInstantMessagingSupport>)_serviceApplication plugInDidReceiveMessage:message fromHandle:handle];
				break;
			}
				
			default:
				break;
		}
	}
}

- (NSString *)handleForSteamFriend:(SKSteamFriend *)friend
{
	return [[NSNumber numberWithUnsignedLongLong:[friend steamId]] stringValue];
}

- (void) steamClientDidRecievePersonaState:(NSNotification *)notification
{
	SKSteamPersonaStateInfo * info = [notification steamInfo];
	SKSteamFriend * friend = [info steamFriend];
	if (friend != nil)
	{
		CRLog(@"Got persona state for %@", friend.personaName);
		
		[self updateFriend:friend withAvatarData:nil];
	}
}

- (void) updateFriend:(SKSteamFriend *)friend withAvatarData:(NSData *)data
{
	NSString * handle = [self handleForSteamFriend:friend];
	
	NSMutableDictionary * handleInfo = [[NSMutableDictionary alloc] init];
	
	if (data == nil)
	{
		handleInfo[IMHandlePropertyAlias] = friend.personaName;
		IMHandleAvailability availability;

		switch (friend.personaState)
		{
			case EPersonaStateOnline:
			case EPersonaStateBusy:
			case EPersonaStateLookingToPlay:
			case EPersonaStateLookingToTrade:
				availability = IMHandleAvailabilityAvailable;
				break;
				
			case EPersonaStateAway:
			case EPersonaStateSnooze:
				availability = IMHandleAvailabilityAway;
				break;
				
			case EPersonaStateOffline:
				availability = IMHandleAvailabilityOffline;
				break;
				
			default:
				availability = IMHandleAvailabilityUnknown;
				break;
		}
		
		handleInfo[IMHandlePropertyAvailability] = @(availability);
		
		
		if(friend.avatarHash != nil)
		{
			handleInfo[IMHandlePropertyPictureIdentifier] = friend.avatarHash;
		}
		
		handleInfo[IMHandlePropertyCapabilities] = @[IMHandleCapabilityMessaging];
	}
	else
	{
		handleInfo[IMHandlePropertyPictureData] = data;
	}
	
	[_serviceApplication plugInDidUpdateProperties:[handleInfo copy] ofHandle:handle];
}

- (void) steamClientDidRecieveFriendsList:(NSNotification *)notification
{
	CRLog(@"Got friends list");
	
	NSArray * friends = [notification steamInfo];
	[self updateFriendsList:friends];
}

- (void) updateFriendsList:(NSArray *)friends
{
	NSMutableArray * directFriendHandles = [[NSMutableArray alloc] init];
	
	[friends enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		SKSteamFriend * friend = obj;
		if (friend.relationship == EFriendRelationshipFriend)
		{
			[directFriendHandles addObject:[self handleForSteamFriend:friend]];
		}
	}];
	
	SKSteamFriends * steamFriends = _client.steamFriends;
	
	NSDictionary * defaultGroup = @{ IMGroupListNameKey: [NSString stringWithFormat:@"Steam - %@", steamFriends.personaName],
								  IMGroupListHandlesKey: [directFriendHandles copy],
								  IMGroupListPermissionsKey: @(IMGroupListCanReorderGroup)
								  };
	
	[(id<IMServiceApplicationGroupListSupport>)_serviceApplication plugInDidUpdateGroupList:@[ defaultGroup ] error:nil];
}

- (oneway void) requestGroupList
{
	SKSteamFriends * friends = [_client steamFriends];
	[self updateFriendsList:[friends friends]];
}

- (oneway void) requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier
{
	SKSteamFriends * friends = [_client steamFriends];
	
	uint64_t steamId = [self steamIDOfFriendWithHandle:handle];
	SKSteamFriend * friend = [friends friendWithSteamID:steamId];
	
	NSLog(@"Getting image for avatar identifier %@", identifier);
	
	NSString * hashPrefix = [identifier substringToIndex:2];
	NSString * url = [NSString stringWithFormat:@"http://media.steampowered.com/steamcommunity/public/images/avatars/%@/%@.jpg", hashPrefix, identifier];
	
	NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:[url lowercaseString]]];
	
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * response, NSData * data, NSError * error) {
		NSLog(@"Response for %@: %@", request, response);
		if (data != nil)
		{
			[self updateFriend:friend withAvatarData:data];
		}
	}];
}

@end
