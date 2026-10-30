#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 调试标记：/var/mobile/HelloWorld-<tag> 出现即代表对应阶段已执行（验证用，后续可移除）。
static void HelloMark(NSString *tag) {
    NSString *path = [@"/var/mobile/HelloWorld-" stringByAppendingString:tag];
    [[tag dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
}

// 自己持有一个高层级窗口承载弹窗，避免直接向 SpringBoard 的 rootViewController 弹出时被静默忽略。
static UIWindow *gHelloAlertWindow = nil;
static BOOL gHelloAlertShown = NO;

static BOOL HelloShowAlert(void) {
    if (gHelloAlertShown) {
        return YES;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            HelloShowAlert();
        });
        return NO;
    }

    UIApplication *app = [UIApplication sharedApplication];
    if (!app) {
        return NO;
    }

    // 等 SpringBoard 至少有一个可见窗口，代表主界面已经起来了。
    UIWindow *host = nil;
    for (UIWindow *window in app.windows) {
        if (!window.isHidden && window.alpha > 0.0) {
            host = window;
            break;
        }
    }
    if (!host) {
        return NO;
    }

    gHelloAlertShown = YES;

    UIWindow *alertWindow = [[UIWindow alloc] initWithFrame:host.bounds];
    alertWindow.windowLevel = UIWindowLevelAlert + 1;
    alertWindow.backgroundColor = [UIColor clearColor];

    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    alertWindow.rootViewController = root;
    [alertWindow makeKeyAndVisible];
    gHelloAlertWindow = alertWindow;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Hello World"
                                            message:@"SpringBoard 已重启，插件加载成功。"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        gHelloAlertWindow.hidden = YES;
        gHelloAlertWindow = nil;
        HelloMark(@"dismissed");
    }]];
    [root presentViewController:alert animated:YES completion:^{
        HelloMark(@"shown");
    }];
    NSLog(@"[HelloWorld] alert requested");
    return YES;
}

// SpringBoard 启动瞬间主界面可能还没准备好，按秒重试有限次。
static void HelloTryShowAlert(NSUInteger remaining) {
    if (HelloShowAlert() || remaining == 0) {
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        HelloTryShowAlert(remaining - 1);
    });
}

// 启动完成后延时尝试弹窗；多个触发入口共用，靠 gHelloAlertShown 去重。
static void HelloScheduleAlert(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        HelloTryShowAlert(10);
    });
}

%ctor {
    @autoreleasepool {
        NSLog(@"[HelloWorld] Loaded");
        HelloMark(@"ctor");

        // 触发入口一：SpringBoard 启动完成通知。
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
            HelloMark(@"notification");
            HelloScheduleAlert();
        }];

        // 兜底路径：注入晚于启动通知时（例如插件被延迟加载），再单独尝试一次。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            HelloTryShowAlert(0);
        });
    }
}

// 触发入口二：直接 hook SpringBoard 的启动完成回调，比通知更贴近本进程实际时序。
%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    HelloMark(@"didFinishLaunching");
    HelloScheduleAlert();
}

%end
