#import <UIKit/UIKit.h>

@interface PointMarker : NSObject

@property (nonatomic, assign) float     x;
@property (nonatomic, assign) float     y;
@property (nonatomic, assign) float     xSize;
@property (nonatomic, assign) float     ySize;
@property (nonatomic, assign) int       threshold;
@property (nonatomic, copy) NSString*   name;

- (id)initWithX:(float)x y:(float)y xSize:(float)xSize ySize:(float)ySize threshold:(int)threshold;

- (float)distanceToMarker:(PointMarker*)marker;

- (float)angleToMarker:(PointMarker*)marker;

@end
