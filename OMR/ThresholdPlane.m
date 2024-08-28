//
//  ThresholdPlane.m
//  OMR
//
//  Created by Kees van der Bent on 12/05/12.
//  Copyright (c) 2012 Software Natural. All rights reserved.
//

#import "ThresholdPlane.h"

// http://paulbourke.net/geometry/pointlineplane/ : Equation of 3D plane: ax + by + cz + d = 0.
// Here threshold is the Z direction.

@interface ThresholdPlane ()
{
    float   a;
    float   b;
    float   c;
    float   d;
}

@end


@implementation ThresholdPlane


- (id)initWithPointMarkers:(NSArray*)pointMarkers
{
    if (self = [super init])
    {
        float   x1 = ((PointMarker*)[pointMarkers objectAtIndex:0]).x;
        float   y1 = ((PointMarker*)[pointMarkers objectAtIndex:0]).y;
        float   z1 = ((PointMarker*)[pointMarkers objectAtIndex:0]).threshold;
        float   x2 = ((PointMarker*)[pointMarkers objectAtIndex:1]).x;
        float   y2 = ((PointMarker*)[pointMarkers objectAtIndex:1]).y;
        float   z2 = ((PointMarker*)[pointMarkers objectAtIndex:1]).threshold;
        float   x3 = ((PointMarker*)[pointMarkers objectAtIndex:2]).x;
        float   y3 = ((PointMarker*)[pointMarkers objectAtIndex:2]).y;
        float   z3 = ((PointMarker*)[pointMarkers objectAtIndex:2]).threshold;
        
        a = y1 * (z2 - z3) + y2 * (z3 - z1) + y3 * (z1 - z2);
        b = z1 * (x2 - x3) + z2 * (x3 - x1) + z3 * (x1 - x2);
        c = x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2);
        d = -(x1 * (y2 * z3 - y3 * z2) + x2 * (y3 * z1 - y1 * z3) + x3 * (y1 * z2 - y2 * z1));
    }
    
    return self;
}


// We need to find Z.  Starting from plane equation:
//
//    ax + by + cz + d = 0     =>
//
//    cz = -ax + -by + -d      =>
//
//    z = (-ax + -by + -d) / c
//
- (int)thresholdAtX:(float)x y:(float)y
{
    return (int)roundf((-a * x + -b * y + -d) / c);
}

@end
