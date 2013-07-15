//
//  SteamServicePlugIn.h
//  SteamServicePlugin
//
//  Created by Yaakov on 3/03/13.
//  Copyright (c) 2013 Coding Range. All rights reserved.
//
 
#import <IMServicePlugIn/IMServicePlugIn.h>

@interface SteamServicePlugIn : NSObject <IMServicePlugIn, IMServicePlugInInstantMessagingSupport, IMServicePlugInPresenceSupport, IMServicePlugInGroupListSupport, IMServicePlugInGroupListHandlePictureSupport>

- (id) initWithServiceApplication:(id<IMServiceApplication>)serviceApplication;
- (oneway void) updateAccountSettings:(NSDictionary *)accountSettings;
- (oneway void) login;
- (oneway void) logout;
- (oneway void) userDidStartTypingToHandle:(NSString *)handle;
- (oneway void) userDidStopTypingToHandle:(NSString *)handle;
- (oneway void) sendMessage:(IMServicePlugInMessage *)message toHandle:(NSString *)handle;
- (oneway void) updateSessionProperties:(NSDictionary *)properties;
- (oneway void) requestGroupList;
- (oneway void) requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier;

@end
