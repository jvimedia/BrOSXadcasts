//
//  AppDelegate.h
//  OSXBroadcasts
//
//  Created by Max Nuding on 31/07/14.
//  Copyright (c) 2014 Max Nuding. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *sysBarMenu;
@property (strong, nonatomic) NSMenuItem *authItem;
@property (strong, nonatomic) NSMenuItem *quitItem;
@property (strong, nonatomic) NSMenuItem *donateItem;

@end

