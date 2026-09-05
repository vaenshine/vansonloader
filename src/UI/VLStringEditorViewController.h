#import <UIKit/UIKit.h>
#import "VLStringMemorySession.h"

@interface VLStringEditorViewController : UIViewController
@property(nonatomic, strong) VLStringMemorySession *session;
@property(nonatomic) uint64_t initialAddress;
@property(nonatomic, copy) void (^didChangeMemory)(void);
@end
