#import "StartUp.h"
#import "WebKit/WKWebView.h"

@implementation StartUp {
    NSString *OriginUrl;
    NSInteger loadingTries;
    NSDictionary *savedManifest;
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

-(void)ScriptsLoadingComplete:(CDVInvokedUrlCommand *)command
{
    if(!savedManifest) {
        NSLog(@"No saved manifest!");
        return;
    }
    NSString *run = [savedManifest valueForKey:@"run"];
    [self runScript:run withBlock:^(id result) {
    }];
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

-(void)loadingProcess
{
    NSError *err = nil;
    NSData *manifestData = [NSData dataWithContentsOfURL:[NSURL URLWithString:OriginUrl] options:NSDataReadingUncached error:&err];
    if(err) {
        NSLog(@"Can not download manifest %@: %@", OriginUrl, err);
        loadingTries -= 1;
        if(loadingTries >= 0) {
            [self performSelector:@selector(loadingProcess) withObject:nil afterDelay:0.5f];
        } else {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Loading error", @"") message:NSLocalizedString(@"Check your Internet connection and try again", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
            [av show];
        }
        return;
    }
    id manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&err];
    if(err) {
        NSLog(@"Can not parse manifest %@:\n%@", OriginUrl, [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding]);
        return;
    }
    NSLog(@"Manifest: %@", manifest);
    if([manifest isKindOfClass:NSDictionary.class]) {
        savedManifest = manifest;
        NSDictionary *scripts = [manifest valueForKey:@"scripts"];
        NSMutableArray *list = [NSMutableArray new];
        NSArray *scrIos = [scripts valueForKey:@"ios"];
        for(NSString *scr in scrIos) {
            //[self injectScriptTagWithSrc:scr];
            [list addObject:scr];
        }
        NSArray *scrAll = [scripts valueForKey:@"all"];
        for(NSString *scr in scrAll) {
            //[self injectScriptTagWithSrc:scr];
            [list addObject:scr];
        }
//        NSString *run = [manifest valueForKey:@"run"];
//        [self runScript:run withBlock:^(id result) {
//        }];
        NSData *json = [NSJSONSerialization dataWithJSONObject:list options:0 error:&err];
        if(err) {
            NSLog(@"Can not serialize to json: %@", list);
            return;
        }
        NSString *param = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        NSString *loadQueue = [NSString stringWithFormat:@"StartUp.LoadScripts(%@)", param];
        [self runScript:loadQueue withBlock:^(id result) {
            
        }];
    }
}

-(void)pageDidLoaded:(NSNotification*)notification
{
    NSLog(@"Page did loaded");
    loadingTries = 3;
    [self loadingProcess];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    loadingTries = 3;
    [self loadingProcess];
}

@end