#import <Foundation/Foundation.h>
#import "PointMarker.h"

@class CouponFinder;

@protocol CouponFinderDelegate <NSObject>

// When pointMarkers are non-nil, all user markers were inside the image boundaries.
// So the value of pointMarkers can be used to determine if the scan was valid.
- (void)couponFinder:(CouponFinder*)couponFinder 
   foundPointMarkers:(NSArray*)pointMarkers 
    foundUserMarkers:(NSArray*)userMarkers;

@end


@interface CouponFinder : NSObject
{
    UInt8*  pixels;
    int     width;
    int     height;
}


- (id)initWithSpecification:(NSDictionary*)specification
                     pixels:(UInt8*)thePixels 
                      width:(int)theWidth 
                     height:(int)theHeight 
  globalThresholdCorrection:(float)globalThresholdCorrection
   localThresholdCorrection:(float)localThresholdCorrection
                   delegate:(id<CouponFinderDelegate>)delegate;

@end
