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
    
    for (NSUserNotification *n in [center deliveredNotifications]) {
        if ([n.userInfo[@"url"] isEqualToString:notification.userInfo[@"url"]]) {
            return NO; //For some reason this won't work. It returns no but the notification will still display.
        }
    }
    return YES;
}
-(void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[@"url"]]];
    
    //I _really_ should write a method that makes the requests to fight code duplication
    
    NSString *markerURL = @"https://api.app.net/posts/marker";
    NSString *post = [NSString stringWithFormat:@"{ \"name\": \"channel:%d\", \"id\": \"%d\" }", [notification.userInfo[@"channel"] intValue], [notification.userInfo[@"id"] intValue]];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu",(unsigned long)[postData length]];
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:markerURL]];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %@",
                   [self.prefs objectForKey:@"usertoken"]] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [req setHTTPBody:postData];
    NSURLResponse *response;
    NSError *error = nil;
    [NSURLConnection sendSynchronousRequest:req
                          returningResponse:&response
                                      error:&error];
    //I'll just ignore the server response for now, will change later and check for errors
    
    /*NSData *data = [NSURLConnection sendSynchronousRequest:req
                                         returningResponse:&response
                                                    error:&error];*/
    /*if(error!=nil) {
        NSLog(@"ADN Error:%@", error);
    } else {
        if (data != nil) {
            NSError *jError = nil;
            NSDictionary* json =[NSJSONSerialization
                                 JSONObjectWithData:data
                                 options:kNilOptions
                                 error:&jError];
        }
    }*/
    [center removeDeliveredNotification:notification];

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
    self.quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@""];
    self.donateItem = [[NSMenuItem alloc] initWithTitle:@"Donate" action:@selector(donate) keyEquivalent:@""];
    if (self.user_token == nil) {
        self.authItem = [[NSMenuItem alloc] initWithTitle:@"Authorize" action:@selector(authorize) keyEquivalent:@""];
    } else {
        self.authItem = [[NSMenuItem alloc] initWithTitle:@"Deauthorize" action:@selector(deauthorize) keyEquivalent:@""];
        [self loadChannels];
    }
    [self.sysBarMenu addItem:self.authItem];
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://account.app.net/oauth/authenticate?client_id=k3MDrXg8hfSUn8qzva7JXF4fBgp7E6zJ&response_type=token&redirect_uri=osxbroadcasts://&scope=public_messages"]];
}

-(void)deauthorize {
    [self.prefs setObject:nil forKey:@"usertoken"];
    [self.prefs synchronize];
    self.authItem.title = @"Authorize";
    self.authItem.action = @selector(authorize);
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification {
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSString *token = [urlString componentsSeparatedByString:@"access_token="][1];
    [self.prefs setObject:token forKey:@"usertoken"];
    [self.prefs synchronize];
    self.authItem.title = @"Deauthorize";
    self.authItem.action = @selector(deauthorize);
    [self loadChannels];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(void)loadChannels {
    /*[self displayNotificationWithIDs:@[[NSNumber numberWithInt:39963],
                                       [NSNumber numberWithInt:4460197]]];*/
    NSURL *channelURL = [NSURL URLWithString:@"https://api.app.net/channels?include_marker=1"];
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
                   [self.prefs objectForKey:@"usertoken"]] forHTTPHeaderField:@"Authorization"]; //I've found out how to do it without headers afterwards. Yay. Too lazy to change though
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
        }
    }
    //We have to do the check here since in userNotificationCenter:shouldPresentNotification: happily ignores the return value
    bool shouldDisplay = YES;
    for (NSUserNotification *n in [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications]) {
        if ([n.userInfo[@"url"] isEqualToString:url]) {
            shouldDisplay = NO;
        }
    }
    if (shouldDisplay) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = title;
        notification.informativeText = subtitle;
        notification.soundName = NSUserNotificationDefaultSoundName;
        notification.hasActionButton = NO;
        notification.userInfo = @{@"url": url, @"channel" : (NSNumber*)ids[0], @"id" : (NSNumber*)ids[1]};
        notification.contentImage = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
    
}

@end
