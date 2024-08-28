#import <UIKit/UIKit.h>

@interface Common : NSObject

+ (id)objectWithJsonData:(NSData*)data;

+ (NSData*)jsonDataWithObject:(id)object;

+ (id)objectWithFile:(NSString*)fileName;

@end
