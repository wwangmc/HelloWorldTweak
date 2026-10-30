#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 同一个 SpringBoard 生命周期内只弹一次，避免重复展示。
static BOOL gHelloAlertShown = NO;

static UIViewController *HelloTopViewController(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) {
        return nil;
    }

    UIWindow *keyWindow = nil;
    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow && !window.isHidden && window.alpha > 0.0) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) {
        for (UIWindow *window in [app.windows reverseObjectEnumerator]) {
            if (!window.isHidden) {
                keyWindow = window;
                break;
            }
        }
    }

    UIViewController *controller = keyWindow.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

// 返回 YES 表示弹窗已经展示（或已经展示过），NO 表示当前还拿不到可用的视图控制器。
static BOOL HelloShowAlert(void) {
    if (gHelloAlertShown) {
        return YES;
    }

    UIViewController *presenter = HelloTopViewController();
    if (!presenter) {
        return NO;
    }
    gHelloAlertShown = YES;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Hello World"
                                            message:@"SpringBoard 已重启，插件加载成功。"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
    NSLog(@"[HelloWorld] alert presented by %@", NSStringFromClass([presenter class]));
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

// 启动完成后延时尝试弹窗；两个触发入口共用，互不重复。
static void HelloScheduleAlert(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        HelloTryShowAlert(8);
    });
}

%ctor {
    @autoreleasepool {
        NSLog(@"[HelloWorld] Loaded");

        // 触发入口一：SpringBoard 启动完成通知。
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
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
    HelloScheduleAlert();
}

%end
