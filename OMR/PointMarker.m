#import "PointMarker.h"

@implementation PointMarker

@synthesize x         = _x;
@synthesize y         = _y;
@synthesize xSize     = _xSize;
@synthesize ySize     = _ySize;
@synthesize threshold = _threshold;
@synthesize name      = _name;

- (id)initWithX:(float)x y:(float)y xSize:(float)xSize ySize:(float)ySize threshold:(int)threshold
{
    if (self = [super init])
    {
        _x         = x;
        _y         = y;
        _xSize     = xSize;
        _ySize     = ySize;
        _threshold = threshold;
    }
    
    return self;
}


- (void)dealloc
{
    [_name release];
    
    [super dealloc];
}


- (float)distanceToMarker:(PointMarker*)marker
{
    return sqrtf((self.x - marker.x) * (self.x - marker.x) +
                 (self.y - marker.y) * (self.y - marker.y));
}


// Angle between the line defined by two points and the horizontal axis.
- (float)angleToMarker:(PointMarker*)marker
{    
    return atan2f(marker.y - self.y, marker.x - self.x) * 180 / M_PI;
}


/* 
 B. The angle bewteen the vectors OP1 and OP2 (O being the origin), 
 you should know that the dot product between two vectors u and v is:
 
 u . v = u.x * v.x + u.y * v.y = |u|*|v|*cos(a)
 
 a being the angle between the vectors.  So the angle is given by:
 
 double n1 = sqrt(x1 * x1 + y1 * y1);
 double n2 = sqrt(x2 * x2 + y2 * y2);
 double angle = acos((x1 * x2 + y1 * y2) / (n1 * n2)) * 180 / PI;
 */

@end
