#import <UIKit/UIKit.h>
#import "CouponFinder.h"
#import "AppDelegate.h"
#import "ThresholdPlane.h"

#define HistogramSize 32        // Must be power of 2.
#define SpaceMinimum   3        // Minimum number of white pixels around.
#define BorderMinimum  3        // Minimum number of pixels in Border.
#define RingMinimum    3        // Minimum number of pixels in Ring.
#define CenterMinimum  6        // Minimum number of pixels in Center.
#define CountMinimum   3        // Mimimum number of found marker patterns.
#define CountMaximum  64        // Maximum number of marker patterns.
#define SkipSize       2        // Number of lines to skip when nothing found.
#define AngleMargin    2        // Margin allows in 90 degrees angle.


@interface CouponFinder ()
{
    int             histogram[HistogramSize];
    int             threshold;
    float           globalCorrection;
    float           localCorrection;
    
    int             beginSpace;     // Light, 1 unit or more.
    int             beginBorder;    // Dark,  1 unit.
    int             beginRing;      // Light, 1 unit.
    int             center;         // Dark,  3 units.
    int             endRing;        // Light, 1 unit.
    int             endBorder;      // Dark,  1 Unit.
    int             endSpace;       // Light, 1 unit or more.    
    
    ThresholdPlane* thresholdPlane;
}

- (NSArray*)findPointMarkers;

- (int)intensityAtX:(int)x y:(int)y;

- (NSArray*)sortPointMarkers:(NSArray*)inPointMarkers;

- (float)determineScaleOfPointMarkers:(NSArray*)pointMarkers specification:(NSDictionary*)specification;

- (float)determineAngleOfPointMarkers:(NSArray*)pointMarkers specification:(NSDictionary*)specification;

- (PointMarker*)determineField:(NSDictionary*)field 
                         scale:(float)scale 
                         angle:(float)angle 
                       offsetX:(float)offsetX 
                       offsetY:(float)offsetY
                   insideImage:(BOOL*)insideImage;

@end


@implementation CouponFinder

- (id)initWithSpecification:(NSDictionary*)specification
                     pixels:(UInt8*)thePixels 
                      width:(int)theWidth 
                     height:(int)theHeight 
  globalThresholdCorrection:(float)globalThresholdCorrection
   localThresholdCorrection:(float)localThresholdCorrection
                   delegate:(id<CouponFinderDelegate>)delegate
{
    if (self = [super init])
    {
        NSArray*        pointMarkers;
        NSMutableArray* userMarkers;
        float           scale;
        float           angle;
        float           offsetX;    // We currently assume that corner-marker is at origin.
        float           offsetY;
        
        pixels           = thePixels;
        width            = theWidth;
        height           = theHeight;
        globalCorrection = globalThresholdCorrection;
        localCorrection  = localThresholdCorrection;
                    
        pointMarkers = [self findPointMarkers];
        
        if ([pointMarkers count] == 3)
        {
            // Returns nil when angle of approximately 90 degress is not found.
            pointMarkers = [self sortPointMarkers:pointMarkers];
            
            if (pointMarkers != nil)
            {
                userMarkers = [NSMutableArray array];
                
                thresholdPlane = [[ThresholdPlane alloc] initWithPointMarkers:pointMarkers];
                
                // Here we have a sorted markers: left, corner, bottom.
                
                scale   = [self determineScaleOfPointMarkers:pointMarkers specification:specification];
                angle   = [self determineAngleOfPointMarkers:pointMarkers specification:specification];
                offsetX = ((PointMarker*)[pointMarkers objectAtIndex:1]).x;
                offsetY = ((PointMarker*)[pointMarkers objectAtIndex:1]).y;
                
                // NSLog(@"SCALE=%2.0f  ANGLE=%4.0f  OFFSET_X=%3.0f  OFFSET_Y=%3.0f", scale, angle, offsetX, offsetY);
                
                for (NSDictionary* field in [specification objectForKey:@"fields"])
                {
                    BOOL    insideImage;
                    
                    PointMarker* marker = [self determineField:field
                                                         scale:scale 
                                                         angle:angle
                                                       offsetX:offsetX 
                                                       offsetY:offsetY
                                                   insideImage:&insideImage];
                    marker.name = [field objectForKey:@"name"];

                    if (insideImage == NO)
                    {
                        pointMarkers = nil;
                        userMarkers  = nil;
                        break;
                    }
                    
                    if (marker != nil)
                    {
                        [userMarkers addObject:marker];
                    }
                }
                
                [delegate couponFinder:self foundPointMarkers:pointMarkers foundUserMarkers:userMarkers];
            }
            else
            {
                [delegate couponFinder:self foundPointMarkers:nil foundUserMarkers:nil];
           }
        }
        else 
        {
            [delegate couponFinder:self foundPointMarkers:nil foundUserMarkers:nil];
        }
    }
    
    return self;
}


- (void)dealloc
{    
    [thresholdPlane release];
    
    [super dealloc];
}


- (void)resetCounts
{
    beginSpace = beginBorder = beginRing = center = endRing = endBorder = endSpace = 0;                        
}


// Calculate average of lowest and highest peak.  This assumes that intensity
// increases have the same effect at the low and high end.  This is however not
// true.  It would be better to take into account that an intensity increase has
// a much larger effect on the low end, than on the high end.  Doing so would
// shift the threshold more to the low end.  I saw a tangent being used on a
// Wikipedia page about image contrast; this seems to be the right direction:
// http://en.wikipedia.org/wiki/Image_editing#Contrast_change_and_brightening
// But for now, the lineair average seems to be good enough.
//
// The algorithm assumes that there are (at least) two peaks.  When there is one
// peak, the threshold ends up being this peak; which will probably give invalid
// results, when used.
//
// The histogram size (32 buckets of 8 values) has been determined emperically.
// It gives a good historgram spread for iPad images of a white coupon with
// black markers.  But I think that this histogram size is close to optimal for
// the general case of a light image with dark objects.
//
// Example:
//
// |
// |                    #
// |                 #####
// |      #       #########
// |    ###  #   ###########
// |  ########################
// +-------------------------------
//        ^             ^
//        6             19
//
// Threshold = ((6 + 19) * (256 / 32)) / 2 = 100.
//
- (int)peakAverageHistogramThreshold
{
    int low   = 0;
    int high  = 0;
    
    for (int i = 0, peak = 0; i < HistogramSize; i++)
    {
        if (histogram[i] > peak)
        {
            peak = histogram[i];
            low = i;
        }
        else if (histogram[i] < peak)
        {
            break;
        }
    }
    
    for (int i = (HistogramSize - 1), peak = 0; i >= 0; i--)
    {
        if (histogram[i] > peak)
        {
            peak = histogram[i];
            high = i;
        }
        else if (histogram[i] < peak)
        {
            break;
        }
    }
    
    return ((low + high) * (256 / HistogramSize)) / 2.0f;
}


// To determine the threshold about 10,000 samples, equally spread over the image,
// are taken.  This is done in a raster of about 100 in X, and 100 in Y direction.
- (int)determineThreshold
{
    int bucketSize = 256 / HistogramSize;
    int xIncrement = (width  + (100 / 2)) / 100;    // Rounded by adding half of 100.
    int yIncrement = (height + (100 / 2)) / 100;    // Rounded by adding half of 100.
    
    memset(histogram, 0, sizeof(histogram));
    
    // Iterate X in inner loop, for better CPU cache performance.
    for (int y = 0; y < height; y += yIncrement)
    {
        for (int x = 0; x < width; x += xIncrement)
        {
            const UInt8*    pixel = pixels + (x + (width * y)) * 4;
            int             value;
            
            // Order is BGRA.  Red and alpha are discarded.
            value = (pixel[0] + pixel[1]) / 2;
            
            histogram[(value + (bucketSize / 2)) / bucketSize]++;   // Round by adding half bucket size.
        }
    }
    
    return [self peakAverageHistogramThreshold];        
}


// Determine the threshold in a certain area.
- (int)determineThresholAtCenterX:(int)centerX centerY:(int)centerY size:(int)size
{
    int bucketSize = 256 / HistogramSize;
    int xIncrement = 1;
    int yIncrement = 1;
    int localThreshold;
    
    memset(histogram, 0, sizeof(histogram));
    
    // Iterate X in inner loop, for better CPU cache performance.
    for (int y = centerY - (size / 2); y < centerY + (size / 2); y += yIncrement)
    {
        for (int x = centerX - (size / 2); x < centerX + (size / 2); x += xIncrement)
        {
            const UInt8*    pixel = pixels + (x + (width * y)) * 4;
            int             value;
            
            // Order is BGRA.  Red and alpha are discarded.
            value = (pixel[0] + pixel[1]) / 2;
            
            histogram[(value + (bucketSize / 2)) / bucketSize]++;   // Round by adding half bucket size.
        }
    }
    
    localThreshold = [self peakAverageHistogramThreshold];
    
    return localThreshold;
}


// http://raidenii.net/files/datasheets/misc/qr_code.pdf (see chapters 11-13).
// The ratio's of the dark-light-dark-light-dark pattern when passing a QR-marker
// is 1:1:3:1:1 units.  So a unit is a number of pixels.  According to the above
// document, a margin of +/- 0.5 should be taken for each of the ratio's.
//
// Using these QR-marker values for our circular point-markers, seems to work well.
// But we may need to revisit this later to optimize/correct.
//
// This method determines if there is a single unit that fits the margins of
// all five measured widths.  It does this by first determining the highest
// minimum unit, and then checks if this unit is lower than each of the five
// maximum units.  Below is an example:
//
// Begin-Border:        min |-------------------------------| max
//   Begin-Ring:    |-----------------------------|
//       Center:                         |-------------------------------------|
//     End-Ring:               |-------------------------------------|
//   End-Border:  |----------------------------|
//
//   Found unit:                          ^
- (float)findUnit
{
    float   unit = 0.0f;

    float   beginBorderUnitMin = beginBorder / 1.5f;
    float   beginBorderUnitMax = beginBorder / 0.5f;
    float   beginRingUnitMin   = beginRing   / 1.5f;
    float   beginRingUnitMax   = beginRing   / 0.5f;
    float   centerUnitMin      = center      / 3.5f;
    float   centerUnitMax      = center      / 2.5f;
    float   endRingUnitMin     = endRing     / 1.5f;
    float   endRingUnitMax     = endRing     / 0.5f;
    float   endBorderUnitMin   = endBorder   / 1.5f;
    float   endBorderUnitMax   = endBorder   / 0.5f;
    
    unit = (beginBorderUnitMin > unit) ? beginBorderUnitMin : unit;
    unit = (beginRingUnitMin   > unit) ? beginRingUnitMin   : unit;
    unit = (centerUnitMin      > unit) ? centerUnitMin      : unit;
    unit = (endRingUnitMin     > unit) ? endRingUnitMin     : unit;
    unit = (endBorderUnitMin   > unit) ? endBorderUnitMin   : unit;
    
    if (unit <= beginBorderUnitMax &&
        unit <= beginRingUnitMax   &&
        unit <= centerUnitMax      &&
        unit <= endRingUnitMax     &&
        unit <= endBorderUnitMax)
    {
        return unit;
    }
    else
    {
        return 0.0f;
    }
}


- (int)findPatternAtY:(int)y fromX:(int)fromX toX:(int)toX
{
    [self resetCounts];
    
    for (int x = fromX; x < toX; x++)
    {            
        int     intensity = [self intensityAtX:x y:y];
        BOOL    isLight   = intensity > threshold * globalCorrection;
        
        if (isLight)
        {
            if (beginBorder == 0)
            {
                beginSpace++;
            }
            else if (beginBorder >= BorderMinimum && center == 0)
            {
                beginRing++;
            }
            else if (center >= CenterMinimum && endBorder == 0)
            {
                endRing++;
            }
            else if (endBorder >= BorderMinimum)
            {                
                if (++endSpace == SpaceMinimum)
                {
                    if ([self findUnit] != 0.0f)
                    {
                        return x - endSpace - endBorder - endRing - center - beginRing - beginBorder;
                    }
                    else
                    {
                        [self resetCounts];
                    }
                }
            }
            else
            {
                [self resetCounts];
            }
        }
        else // dark
        {
            if (beginSpace >= SpaceMinimum && beginRing == 0)
            {
                beginBorder++;
            }
            else if (beginRing >= RingMinimum && endRing == 0)
            {
                center++;
            }
            else if (endRing >= RingMinimum)
            {
                endBorder++;
            }
            else
            {
                [self resetCounts];
            }
        }
    }    
    
    return 0;
}


- (int)findPatternAtX:(int)x fromY:(int)fromY toY:(int)toY
{
    [self resetCounts];
    
    for (int y = fromY; y < toY; y++)
    {            
        int     intensity = [self intensityAtX:x y:y];
        BOOL    isLight   = intensity > threshold * globalCorrection;
        
        if (isLight)
        {
            if (beginBorder == 0)
            {
                beginSpace++;
            }
            else if (beginBorder >= BorderMinimum && center == 0)
            {
                beginRing++;
            }
            else if (center >= CenterMinimum && endBorder == 0)
            {
                endRing++;
            }
            else if (endBorder >= BorderMinimum)
            {                
                if (++endSpace == SpaceMinimum)
                {
                    if ([self findUnit] != 0.0f)
                    {
                        return y - endSpace - endBorder - endRing - center - beginRing - beginBorder;
                    }
                    else
                    {
                        [self resetCounts];
                    }
                }
            }
            else
            {
                [self resetCounts];
            }
        }
        else // dark
        {
            if (beginSpace >= SpaceMinimum && beginRing == 0)
            {
                beginBorder++;
            }
            else if (beginRing >= RingMinimum && endRing == 0)
            {
                center++;
            }
            else if (endRing >= RingMinimum)
            {
                endBorder++;
            }
            else
            {
                [self resetCounts];
            }
        }
    }    
        
    return 0;
}


- (int)calculateSize
{
    return beginBorder + beginRing + center + endRing + endBorder;
}


- (void)blockAreaAtX:(int)x y:(int)y size:(int)size
{
    for (int Y = y - (size / 2); Y < y + (size / 2); Y++)
    {
        for (int X = x - (size / 2); X < x + (size / 2); X++)
        {
            if (X > 0 && X < width && Y > 0 && Y < height)
            {
                UInt8*  pixel = pixels + (X + (width * Y)) * 4;
                pixel[0] = 0;
                pixel[1] = 0;
                pixel[2] = 0;
            }
        }
    }
}


- (NSArray*)findPointMarkers
{    
    int             foundX[CountMaximum];   // X-coordinates of where point-marker begins.
    int             sizesX[CountMaximum];   // Horizontal point-marker sizes.  Point-marker end: found-X + size-X.
    int             foundY[CountMaximum];   // Y-coordinates of where point-marker begins.
    int             sizesY[CountMaximum];   // Vertical point-marker sizes.  Point-marker end: found-Y + size-Y.
    int             countX;
    int             countY;
    
    int             fromX;
    int             toX;
    int             fromY;
    int             toY;
    
    int             size;
    
    NSMutableArray* pointMarkers = [NSMutableArray array];
    
    threshold = [self determineThreshold];

    for (int y = 0; y <= height; y += SkipSize)
    {
        if ((foundX[0] = [self findPatternAtY:y fromX:0 toX:width]) != 0)
        {            
            size = [self calculateSize];
            sizesX[0] = size;

            // Scan further in X direction.
            fromY  = y - (SkipSize - 1);
            toY    = fromY + size; // We're at center: about (size / 2); double for slanted.
            fromX  = foundX[0] - (size / 8) - SpaceMinimum;
            toX    = foundX[0] + size + (size / 4) + SpaceMinimum;            
            countX = 1;
            for (int Y = fromY; Y < toY && countX < CountMaximum; Y++)
            {
                foundX[countX] = [self findPatternAtY:Y fromX:fromX toX:toX];
                sizesX[countX] = [self calculateSize];
                countX += (foundX[countX] != 0);
            }
    
            if (countX >= CountMinimum)
            {
                // Now scan in Y direction.
                fromY  = y - (size / 2) - SpaceMinimum;
                toY    = fromY + (2 * size) + (2 * SpaceMinimum);
                fromX  = foundX[0] - (size  / 8);
                toX    = foundX[0] + size;
                countY = 0;
                for (int x = fromX; x < toX && countY < CountMaximum; x++)
                {
                    foundY[countY] = [self findPatternAtX:x fromY:fromY toY:toY];
                    sizesY[countY] = [self calculateSize];
                    countY += (foundY[countY] != 0);                    
                }
                
                if (countY >= CountMinimum)
                {
                    // Take center found X and Y.
                    int X;
                    int Y;
                    int localThreshold;
                    
                    // Take center lines; good enough to get center of our circular marker.
                    X = foundX[countX / 2] + sizesX[countX / 2] / 2;
                    Y = foundY[countY / 2] + sizesY[countY / 2] / 2;

                    localThreshold = [self determineThresholAtCenterX:X centerY:Y 
                                                                 size:MAX(sizesX[countX / 2], 
                                                                          sizesY[countY / 2])];

                    //  NSLog(@"CountX (%3d,%3d): %d, %d", X, Y, countX, countY);

                    // Make the area of the current marker black, so it will be
                    // skipped.  In this way markers that are behind (in the X
                    // direction) this one can be found.
                    //
                    // This adds some overhead, as the lines from current value 
                    // of y will be visited again fully.  Alternative ideas were
                    // much more complicated, and it's relative small overhead
                    // because a marker normally will spread accross less than 
                    // 50 lines.
                    [self blockAreaAtX:X y:Y size:MAX(sizesX[countX / 2], sizesY[countY / 2])];   
                    y -= SkipSize;
                    
                    PointMarker*    marker = [[PointMarker alloc] initWithX:X 
                                                                          y:Y 
                                                                      xSize:sizesX[countX / 2] 
                                                                      ySize:sizesY[countY / 2]
                                                                  threshold:localThreshold];
                    [pointMarkers addObject:marker];
                    [marker release];
                }
            }
        }
    }    
    
    return pointMarkers;
}


// This method return the pixel intensity at (x,y).  In MainViewController the
// pixel formet kCVPixelFormatType_32BGRA was selected.  This mean that that
// there are 4 bytes per pixel and that the bytes are in order Blue, Green, Red,
// and Alpha.
// 
// Because we want to filter away the coupon's red raster, and because alpha is
// always 255, we discard these two channels.
- (int)intensityAtX:(int)x y:(int)y
{
    // This test avoids having to do these tests all over the place in the core
    // algorithm, which will make things messy.
    if (x < 0 || x >= width || y < 0 || y >= height)
    {
        return 0;
    }
    
    UInt8*  pixel = pixels + (x + (width * y)) * 4;
    
    return (pixel[0] + pixel[1]) / 2;
}


- (int)marginOfAngleA:(float)angleA angleB:(float)angleB
{
    return abs(90 - ((int)fabsf(roundf(angleA - angleB)) % 180));    
}


- (NSArray*)sortPointMarkers:(NSArray*)inPointMarkers
{
    if ([inPointMarkers count] == 3)
    {
        NSMutableArray* outPointMarkers = [NSMutableArray array];
        float           abAngle;
        float           bcAngle;
        float           caAngle;
        float           crossProduct;
        
        PointMarker*    a = [inPointMarkers objectAtIndex:0];
        PointMarker*    b = [inPointMarkers objectAtIndex:1];
        PointMarker*    c = [inPointMarkers objectAtIndex:2];
        
        // http://www.gamedev.net/topic/346146-triangle-orientation/ The cross-
        // product determines if the markers are in clockwise (positive) or
        // counterclockwise (negative) order.  We want to have them in clockwise
        // order; which is an arbitrary choice, we just need one order for further
        // processing.
        crossProduct = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
        if (crossProduct < 0.0f)
        {
            // Swap two to get positive cross-product.
            PointMarker*    temporary;
            
            temporary = a;
            a = b;
            b = temporary;
        }

        abAngle = [a angleToMarker:b];
        bcAngle = [b angleToMarker:c];
        caAngle = [c angleToMarker:a];
        
        // Now see which two angles 'make' approximately 90 degrees.
        if ([self marginOfAngleA:abAngle angleB:bcAngle] < AngleMargin)
        {
            [outPointMarkers addObject:a];
            [outPointMarkers addObject:b];
            [outPointMarkers addObject:c];
        }
        else if ([self marginOfAngleA:bcAngle angleB:caAngle] < AngleMargin)
        {
            [outPointMarkers addObject:b];
            [outPointMarkers addObject:c];
            [outPointMarkers addObject:a];
        }
        else if ([self marginOfAngleA:caAngle angleB:abAngle] < AngleMargin)
        {
            [outPointMarkers addObject:c];
            [outPointMarkers addObject:a];
            [outPointMarkers addObject:b];
        }
        else
        {
            NSLog(@"### %3.0f  %3.0f  %3.0f", abAngle, bcAngle, caAngle);
            
            return nil;
        }
        
        return outPointMarkers;
    }
    else
    {
        return nil;
    }
}


- (BOOL)checkPointMarkersParallel:(NSArray*)pointMarkers specification:(NSDictionary*)specification
{
    return NO;
}


// Scale is pixels/cm.
- (float)determineScaleOfPointMarkers:(NSArray*)pointMarkers specification:(NSDictionary*)specification
{
    float   scale;
    
    float   pixelsAB = [[pointMarkers objectAtIndex:1] distanceToMarker:[pointMarkers objectAtIndex:2]];
    float   cmsAB    = [[[specification objectForKey:@"corner-marker"] objectForKey:@"x"] floatValue] - 
                       [[[specification objectForKey:@"bottom-marker"] objectForKey:@"x"] floatValue];
    
    scale = fabsf(pixelsAB / cmsAB);
    
    return scale;
}


- (float)determineAngleOfPointMarkers:(NSArray*)pointMarkers specification:(NSDictionary*)specification
{
    float   angle;

    angle = [[pointMarkers objectAtIndex:1] angleToMarker:[pointMarkers objectAtIndex:2]];
        
    return angle;
}


- (BOOL)userStrokeAtX:(int)x y:(int)y localThreshold:(int)localThreshold
{
    // This test avoids having to do these tests all over the place in the core
    // algorithm, which will make things messy.
    if (x < 0 || x >= width || y < 0 || y >= height)
    {
        return NO;
    }
    
    UInt8*  pixel = pixels + (x + (width * y)) * 4;
    int     red   = pixel[2];
    int     green = pixel[1];
    int     blue  = pixel[0];
    
    if (red / 2 > green && red / 2 > blue)
    {
        return NO;
    }
    else
    {
        return ((blue + green) / 2) <= localThreshold * localCorrection;
    }
}


- (int)sampleAtX:(float)x y:(float)y size:(float)size localThreshold:(int)localThreshold
{
    int count = 0;
    
    for (int X = roundf(x - (size / 2)); X <= roundf(x + (size / 2)); X++)
    {
        for (int Y = roundf(y - (size / 2)); Y <= roundf(y + (size / 2)); Y++)
        {
            count += [self userStrokeAtX:X y:Y localThreshold:localThreshold];
        }
    }
    
    return count;
}


- (PointMarker*)determineField:(NSDictionary*)field 
                         scale:(float)scale 
                         angle:(float)angle 
                       offsetX:(float)offsetX 
                       offsetY:(float)offsetY
                   insideImage:(BOOL*)insideImage
{
    float cmX    = [[field objectForKey:@"x"] floatValue];
    float cmY    = [[field objectForKey:@"y"] floatValue];
    float pixelX = cmX * scale;
    float pixelY = cmY * scale;
    float newPixelX;
    float newPixelY;
    float size   = [[field objectForKey:@"size"] floatValue] * scale;
    int   sampleValue;
    
    // Now rotate this point around origin.
    newPixelX = cosf(angle / 180.0f * M_PI) * pixelX - sinf(angle / 180.0f * M_PI) * pixelY;
    newPixelY = sinf(angle / 180.0f * M_PI) * pixelX + cosf(angle / 180.0f * M_PI) * pixelY;

    // Then add offset.
    newPixelX += offsetX;
    newPixelY += offsetY;
    
    // Verify that field is within image.
    if (newPixelX - (size / 2) < 0 || newPixelX + (size / 2) >= width ||
        newPixelY - (size / 2) < 0 || newPixelY + (size / 2) >= height)
    {
        *insideImage = NO;
        return nil;
    }
    else
    {
        *insideImage = YES;
    }

    int localThreshold = [thresholdPlane thresholdAtX:newPixelX y:newPixelX];
    
    sampleValue = [self sampleAtX:newPixelX y:newPixelY size:size localThreshold:localThreshold];
    
    if (sampleValue > (size * size / 4))
    {
        return [[[PointMarker alloc] initWithX:newPixelX 
                                             y:newPixelY 
                                         xSize:0 
                                         ySize:0 
                                     threshold:localThreshold] autorelease];            
    }
    else
    {
        return nil;
    }    
}

@end
