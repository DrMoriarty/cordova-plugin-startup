#import "StartUp.h"
#import "WebKit/WKWebView.h"

@implementation StartUp {
    NSString *OriginUrl;
}

- (void)pluginInitialize
{
    // Add notification listener for tracking app activity with FB Events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    // Add notification listener for handleOpenURL
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(openURL:)
                                                 name:CDVPluginHandleOpenURLNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoaded:) name:CDVPageDidLoadNotification object:nil];
    
    NSLog(@"StartUp initialization");
    
    OriginUrl = [self.commandDelegate.settings objectForKey:@"originmanifesturl"];
    NSLog(@"Origin URL: %@", OriginUrl);
}

- (void)applicationDidBecomeActive
{
}

- (void)openURL:(NSNotification *)notification
{
    NSURL *url = [notification object];
}

-(void)runScript:(NSString*)script withBlock:(void(^)(id result))block
{
    if([self.webView isKindOfClass:UIWebView.class]) {
        UIWebView *webView = (UIWebView*)self.webView;
        NSString *result = [webView stringByEvaluatingJavaScriptFromString:script];
        if(block) block(result);
    } else if([self.webView isKindOfClass:WKWebView.class]) {
        WKWebView *webView = (WKWebView*)self.webView;
        [webView evaluateJavaScript:script completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if(error) {
                NSLog(@"Evaluate js error: %@", error);
            }
            if(block) block(result);
        }];
    }
}

-(void)injectScriptTagWithSrc:(NSString*)src
{
    NSString *script = [NSString stringWithFormat:@"var script = document.createElement('script'); script.type = 'text/javascript'; script.src = '%@'; document.getElementsByTagName('head')[0].appendChild(script);", src];
    [self runScript:script withBlock:^(id result) {
        
    }];
}

-(void)pageDidLoaded:(NSNotification*)notification
{
    NSLog(@"Page did loaded");
    NSError *err = nil;
    //NSString *manifest = [NSString stringWithContentsOfURL:[NSURL URLWithString:OriginUrl] encoding:NSUTF8StringEncoding error:&err];
    NSData *manifestData = [NSData dataWithContentsOfURL:[NSURL URLWithString:OriginUrl] options:NSDataReadingUncached error:&err];
    if(err) {
        NSLog(@"Can not download manifest %@: %@", OriginUrl, err);
        return;
    }
    id manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&err];
    if(err) {
        NSLog(@"Can not parse manifest %@:\n%@", OriginUrl, [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding]);
        return;
    }
    NSLog(@"Manifest: %@", manifest);
    if([manifest isKindOfClass:NSDictionary.class]) {
        NSString *run = [manifest valueForKey:@"run"];
        NSDictionary *scripts = [manifest valueForKey:@"scripts"];
        NSArray *scrAll = [scripts valueForKey:@"all"];
        NSArray *scrIos = [scripts valueForKey:@"ios"];
        for(NSString *scr in scrAll) {
            [self injectScriptTagWithSrc:scr];
        }
        for(NSString *scr in scrIos) {
            [self injectScriptTagWithSrc:scr];
        }
        [self runScript:run withBlock:^(id result) {
        }];
    }
    return;
    
//    NSString *cordovaPath = [[NSBundle mainBundle] pathForResource:@"cordova" ofType:@"js" inDirectory:@"www"];
//    NSLog(@"try to load cordova from %@", cordovaPath);
//    NSString *cordovaString = [NSString stringWithContentsOfFile:cordovaPath encoding:NSUTF8StringEncoding error:nil];
//    [self runScript:cordovaString withBlock:^(id result) {
//        NSString *cordovaPluginsPath = [[NSBundle mainBundle] pathForResource:@"cordova_plugins" ofType:@"js" inDirectory:@"www"];
//        NSString *cordovaPluginsScript = [NSString stringWithContentsOfFile:cordovaPluginsPath encoding:NSUTF8StringEncoding error:nil];
//        [self runScript:cordovaPluginsScript withBlock:^(id result) {
//            NSLog(@"Cordova plugins list %@", result);
//        }];
//    }];
}

@end