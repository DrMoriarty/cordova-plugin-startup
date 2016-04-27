//
//  StartUp.h
//
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

@interface StartUp : CDVPlugin <UIAlertViewDelegate>

-(void)ScriptsLoadingComplete:(CDVInvokedUrlCommand*)command;

@end