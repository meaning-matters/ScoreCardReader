#import "AppDelegate.h"

#import "MainViewController.h"

@implementation AppDelegate

@synthesize window             = _window;
@synthesize mainViewController = _mainViewController;

- (void)dealloc
{
    [_window             release];
    [_mainViewController release];
    
    [super dealloc];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    self.mainViewController        = [[[MainViewController alloc] initWithNibName:@"MainViewiPad" 
                                                                           bundle:nil] autorelease];
    self.window.rootViewController = self.mainViewController;
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
