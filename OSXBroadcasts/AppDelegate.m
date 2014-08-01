//
//  AppDelegate.m
//  OSXBroadcasts
//
//  Created by Max Nuding on 31/07/14.
//  Copyright (c) 2014 Max Nuding. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, copy) NSString *user_token;
@property (nonatomic, retain) NSUserDefaults *prefs;
@end

@implementation AppDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}
-(void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[@"url"]]];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    
    self.prefs = [NSUserDefaults standardUserDefaults];
    self.user_token = [self.prefs objectForKey:@"usertoken"];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.title = @"";
    self.statusItem.image = [NSImage imageNamed:@"SysBar"];
    self.statusItem.alternateImage = [NSImage imageNamed:@"SysBar-invert"];
    self.sysBarMenu = [[NSMenu alloc] init];
    self.authItem = [[NSMenuItem alloc] initWithTitle:@"Authorize" action:@selector(authorize) keyEquivalent:@""];
    self.deauthItem = [[NSMenuItem alloc] initWithTitle:@"Deauthorize" action:@selector(deauthorize) keyEquivalent:@""];
    self.quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@""];
    self.donateItem = [[NSMenuItem alloc] initWithTitle:@"Donate" action:@selector(donate) keyEquivalent:@""];
    if (self.user_token == nil) {
        [self.sysBarMenu addItem:self.authItem];
    } else {
        [self.sysBarMenu addItem:self.deauthItem];
        [self loadChannels];
    }
    [self.sysBarMenu addItem:[NSMenuItem separatorItem]];
    [self.sysBarMenu addItem:self.donateItem];
    [self.sysBarMenu addItem:self.quitItem];
    self.statusItem.menu = self.sysBarMenu;
    [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(loadChannels) userInfo:nil repeats:YES];

}

-(void)donate {
     [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=U3E8RJH9YM7EC"]];
}

-(void)quit {
    [NSApp terminate:self];
}
-(void)authorize {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://account.app.net/oauth/authenticate?client_id=k3MDrXg8hfSUn8qzva7JXF4fBgp7E6zJ&response_type=token&redirect_uri=osxbroadcasts://&scope=basic%20public_messages"]];
}

-(void)deauthorize {
    [self.prefs setObject:nil forKey:@"usertoken"];
    [self.prefs synchronize];
    [self.sysBarMenu removeItem:self.deauthItem];
    [self.sysBarMenu addItem:self.authItem];
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification {
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSString *token = [urlString componentsSeparatedByString:@"access_token="][1];
    NSLog(@"%@", token);
    [self.prefs setObject:token forKey:@"usertoken"];
    [self.prefs synchronize];
    [self.sysBarMenu removeItem:self.authItem];
    [self.sysBarMenu addItem:self.deauthItem];
    [self loadChannels];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(void)loadChannels {
    /*[self displayNotificationWithIDs:@[[NSNumber numberWithInt:39963],
                                       [NSNumber numberWithInt:4460197]]];*/
    NSURL *channelURL = [NSURL URLWithString:@"https://api.app.net/channels"];
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:channelURL];
    req.HTTPMethod = @"GET";
    [req setValue:[NSString stringWithFormat:@"Bearer %@",
                   [self.prefs objectForKey:@"usertoken"]] forHTTPHeaderField:@"Authorization"];
    NSURLResponse *response;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req
                                         returningResponse:&response
                                                     error:&error];
    if(error!=nil) {
        NSLog(@"ADN Error:%@", error);
    } else {
        if (data != nil) {
            NSError *jError = nil;
            NSDictionary* json =[NSJSONSerialization
                                 JSONObjectWithData:data
                                 options:kNilOptions
                                 error:&jError];

            for (NSDictionary *dict in json[@"data"]) {
                bool newMessage = [((NSNumber *)dict[@"has_unread"]) boolValue] && [@"net.app.core.broadcast" isEqualToString:dict[@"type"]];
                if (newMessage) {
                    [self performSelectorInBackground:@selector(displayNotificationWithIDs:) withObject:@[dict[@"id"], dict[@"recent_message_id"]]];
                    /*NSLog(@"new messages");
                    NSLog(@"%@", dict);
                    NSLog(@"===============");*/
                }
            }
            
        }
    }
}

-(void)displayNotificationWithIDs:(NSArray *)ids {
    NSString *url = @"";
    NSString *title = @"";
    NSString *subtitle = @"";
    NSString *imageURL = @"";
    NSURL *messageURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.app.net/channels/%d/messages/%d?include_annotations=1", [(NSNumber*)ids[0] intValue], [(NSNumber*)ids[1] intValue]]];
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:messageURL];
    req.HTTPMethod = @"GET";
    [req setValue:[NSString stringWithFormat:@"Bearer %@",
                   [self.prefs objectForKey:@"usertoken"]] forHTTPHeaderField:@"Authorization"];
    NSURLResponse *response;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req
                                         returningResponse:&response
                                                     error:&error];
    if(error!=nil) {
        NSLog(@"ADN Error:%@", error);
    } else {
        if (data != nil) {
            NSError *jError = nil;
            NSDictionary* json =[NSJSONSerialization
                                 JSONObjectWithData:data
                                 options:kNilOptions
                                 error:&jError];
            subtitle = json[@"data"][@"text"];
            imageURL = json[@"data"][@"user"][@"avatar_image"][@"url"];
            for (NSDictionary *d in json[@"data"][@"annotations"]) {
                if ([d[@"type"] isEqualToString:@"net.app.core.crosspost"]) {
                    url = d[@"value"][@"canonical_url"];
                } else if ([d[@"type"] isEqualToString:@"net.app.core.broadcast.message.metadata"]) {
                    title = d[@"value"][@"subject"];
                }
            }
            NSLog(@"New Broadcast: \n\tURL: %@, \n\tTitle: %@ \n\tSubtitle: %@, \n\timageURL: %@, \n\tmessageURL: %@\n===========", url, title, subtitle, imageURL, messageURL);
            
        }
    }
    
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = subtitle;
    notification.soundName = NSUserNotificationDefaultSoundName;
    notification.actionButtonTitle = @"View";
    notification.hasActionButton = YES;
    notification.userInfo = @{@"url": url};
    notification.contentImage = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

@end
