//
//  ThresholdPlane.h
//  OMR
//
//  Created by Kees van der Bent on 12/05/12.
//  Copyright (c) 2012 Software Natural. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PointMarker.h"

@interface ThresholdPlane : NSObject

- (id)initWithPointMarkers:(NSArray*)pointMarkers;

- (int)thresholdAtX:(float)x y:(float)y;

@end
