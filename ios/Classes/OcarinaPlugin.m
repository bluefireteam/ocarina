#import "OcarinaPlugin.h"
#if __has_include(<ocarina/ocarina-Swift.h>)
#import <ocarina/ocarina-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ocarina-Swift.h"
#endif

@implementation OcarinaPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftOcarinaPlugin registerWithRegistrar:registrar];
}
@end
