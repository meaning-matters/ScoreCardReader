// https://developer.apple.com/library/ios/#qa/qa1702/_index.html

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreVideo/CoreVideo.h>
#import "MainViewController.h"
#import "Common.h"

@interface MainViewController ()
{
    NSDictionary*       couponSpecification;
    int                 width;
    int                 height;
    BOOL                active;
    int                 imageCount; // Number of images that need to have same results before accepted.
    AVCaptureDevice*    camera;
}

@end


@implementation MainViewController

@synthesize flipsidePopoverController = _flipsidePopoverController;
@synthesize captureSession            = _captureSession;
@synthesize videoInput                = _videoInput;
@synthesize captureVideoPreviewLayer  = _captureVideoPreviewLayer;
@synthesize crossImageViews           = _crossImageViews;
@synthesize squareImageViews          = _squareImageViews;
@synthesize globalCompensationSlider  = _globalCompensationSlider;
@synthesize localCompensationSlider   = _localCompensationSlider;
@synthesize imageCountLabel           = _imageCountLabel;
@synthesize globalCompensationLabel   = _globalCompensationLabel;
@synthesize localCompensationLabel    = _localCompensationLabel;
@synthesize versionLabel              = _versionLabel;
@synthesize focusModeSegment          = _focusModeSegment;
@synthesize focusModeLabel            = _focusModeLabel;


- (AVCaptureDevice*)backFacingCamera
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionBack)
        {
            NSError*    error = nil;
            
            if ([device lockForConfiguration:&error] == NO)
            {
                NSString*       message = [NSString stringWithFormat:@"Failed to lock camera to modify settings: %@",
                                                                     [error localizedDescription]];
                UIAlertView*    alert = [[UIAlertView alloc] initWithTitle:@"Can't Lock Camera" 
                                                                   message:message 
                                                                  delegate:nil 
                                                         cancelButtonTitle:@"Close"
                                                         otherButtonTitles:nil];
                [alert show];
                [alert release];
            }
                        
            return device;
        }
    }
    
    return nil;
}


- (void)processPixels:(UInt8*)pixels
{
    CouponFinder*   couponFinder = [[CouponFinder alloc] initWithSpecification:couponSpecification
                                                                        pixels:pixels 
                                                                         width:width 
                                                                        height:height
                                                     globalThresholdCorrection:self.globalCompensationSlider.value
                                                      localThresholdCorrection:self.localCompensationSlider.value
                                                                      delegate:self];

    [couponFinder release];
}


// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection
{   
    dispatch_async(dispatch_get_main_queue(), ^()
    {
        self.globalCompensationLabel.text = [NSString stringWithFormat:@"%0.2f", self.globalCompensationSlider.value];
        self.localCompensationLabel.text  = [NSString stringWithFormat:@"%0.2f", self.localCompensationSlider.value];
    });

    if (active == NO)
    {
        return;
    }
    
    CVImageBufferRef    imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    
    width  = CVPixelBufferGetWidth(imageBuffer); 
    height = CVPixelBufferGetHeight(imageBuffer); 

    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    UInt8*              pixels = CVPixelBufferGetBaseAddress(imageBuffer); 
    
    [self processPixels:pixels];    
}


// Create a UIImage from sample buffer data
- (void)setupSession
{   
    camera              = [self backFacingCamera];
    self.videoInput     = [[[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil] autorelease];
    self.captureSession = [[[AVCaptureSession alloc] init] autorelease];
    
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    //self.captureSession.sessionPreset = AVCaptureSessionPresetiFrame960x540;
    
    // Add inputs and output to the capture session
    if ([self.captureSession canAddInput:self.videoInput])
    {
        [self.captureSession addInput:self.videoInput];
    }
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
    [self.captureSession addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
}


- (void)moveImagesToPoints:(NSArray*)pointMarkers imageViews:(NSArray*)imageViews
{
    for (int i = 0; i < [imageViews count]; i++)
    {
       ((UIImageView*)[imageViews objectAtIndex:i]).hidden = YES;
    }
    
    for (int i = 0; i < [pointMarkers count]; i++)
    {
        UIImageView*    imageView = [imageViews objectAtIndex:i];
        PointMarker*    pointMarker; 
        
        if (i < [pointMarkers count])
        {
            pointMarker = [pointMarkers objectAtIndex:i];
            
            imageView.hidden = NO;

            // Analysed image is width * height.  The image is aspect-fill displayed on the
            // screen of 1024 * 786.  The aspect-ratio of the screen is 768 / 1024 = 0.75,
            // and the aspect-ratio of the image is: height / width.  When the aspect-ratio of
            // the screen is larger than that of the image, the image will stick out at the
            // top and bottom of the screen (with device in portrait orientation).  This
            // is the most common case: A.  But otherwise, the image will stick out at the 
            // sides of the screen: B.
            // 
            // The scaling factor between image and screen in case A: 768 / height; this is
            // because the full height is visible.  Then the size of what sticks out is: 
            // (width * scaling-factor - 1024) / 2.
            //
            // For case B the size of what sticks out: (height * scaling-factor - 768) / 2.
            //
            // Here's an example of the normal case A:
            // Analysed image is 960 * 540.  The image is aspect-fill displayed on the
            // screen of 1024 * 786.  This means a scaling factor of 768 / 540 = 1.4222.
            //
            // Then 960 * 1.4222 ~ 1366.  So, at top/bottom of screen, the image sticks
            // out (1366 - 1024) / 2 = 171 pixels (which are not visible).
            //
            // Finally, the X and Y axis of the processed image were swapped wrt the
            // screen coordinate system.  And, the X coordinate is inverted.  This simply
            // has to do with the portret orientation of the app.  Also note that width
            // and height of image and screen are reversed, for the same reason.  But
            // this could be sorted out to make things more logical/symmetric (###).
            
            float   aspectRatioScreen;
            float   aspectRatioImage;
            float   scaleFactor;
            int     x;
            int     y;
            CGRect  screenSize = [[UIScreen mainScreen] bounds];
            float   stickOut;

            aspectRatioScreen = (float)screenSize.size.width / (float)screenSize.size.height;   // iPad: 768 / 1024.
            aspectRatioImage  = (float)height / (float)width;
            
            if (aspectRatioScreen >= aspectRatioImage)
            {
                // case A (normal).
                scaleFactor = (float)screenSize.size.width / (float)height;
                
                stickOut = (width * scaleFactor - screenSize.size.height) / 2.0f;
                
                x = roundf((screenSize.size.width - 1.0f) - (pointMarker.y * scaleFactor)); // -1.0f because x starts a 0.
                y = roundf(pointMarker.x * scaleFactor - stickOut);
            }
            else
            {
                // Case B.
                scaleFactor = (float)screenSize.size.height / (float)width;
                
                stickOut = (height * scaleFactor - screenSize.size.width) / 2.0f;
                
                x = roundf(pointMarker.y * scaleFactor - stickOut);
                y = roundf((screenSize.size.height - 1.0f) - (pointMarker.x * scaleFactor)); // -1.0f because x starts a 0.           
            }
            
            CGRect  rect = [imageView frame];
            
            rect.origin.x = x - 20;
            rect.origin.y = y - 20;
            
            [imageView setFrame:rect];
        }
    }
}


- (BOOL)compareResults:(NSArray*)results
{
    NSArray*    referenceFields = [results lastObject];
    
    for (int i = 0; i < [results count] - 1; i++)
    {
        NSArray*    fields = [results objectAtIndex:i];
        
        if ([fields count] != [referenceFields count])
        {
            return NO;
        }
        
        for (int j = 0; j < [referenceFields count]; j++)
        {
            NSString*   referenceField = ((PointMarker*)[referenceFields objectAtIndex:j]).name;
            NSString*   field          = ((PointMarker*)[fields objectAtIndex:j]).name;
            
            if ([field isEqualToString:referenceField] == NO)
            {
                return NO;
            }
        }
    }
    
    return YES;
}


- (void)couponFinder:(CouponFinder*)couponFinder 
   foundPointMarkers:(NSArray*)pointMarkers
    foundUserMarkers:(NSArray*)userMarkers
{
    static NSMutableArray*  results;
    
    if (results == nil)
    {
        results = [[NSMutableArray alloc] init];
    }

    if (pointMarkers != nil)
    {
        while ([results count] >= imageCount)   // Follows stepper decrement.
        {
            [results removeObjectAtIndex:0];        
        }
        
        if (userMarkers != nil)
        {
            [results addObject:userMarkers];
        }
        
        if ([results count] == imageCount)
        {
            if ([self compareResults:results] == YES)
            {
                active = NO;
                
                // http://iphonedevwiki.net/index.php/AudioServices
                AudioServicesPlaySystemSound(1057);
                
                [results removeAllObjects];
                
                NSString*   message = @"Following fields were found:\n\n";
                
                for (PointMarker* field in userMarkers)
                {
                    message = [message stringByAppendingFormat:@"%@  ", field.name];
                }
 
                dispatch_async(dispatch_get_main_queue(), ^()
                {
                    UIAlertView*    alert = [[UIAlertView alloc] initWithTitle:@"Found Fields" 
                                                                       message:message
                                                                      delegate:self 
                                                             cancelButtonTitle:@"Close"
                                                             otherButtonTitles:nil];
                    [alert show];
                    [alert release];
                });
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^()
    {
        [self moveImagesToPoints:pointMarkers imageViews:self.crossImageViews];
        [self moveImagesToPoints:userMarkers  imageViews:self.squareImageViews];
    });   
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    active = YES;
}


- (void)setupFucusMode
{
    NSMutableArray* supportedModes = [NSMutableArray array];
    int             currentIndex;
    
    if ([camera isFocusModeSupported:AVCaptureFocusModeLocked])
    {
        if ([camera focusMode] == AVCaptureFocusModeLocked)
        {
            currentIndex = [supportedModes count];
        }

        [supportedModes addObject:@"Locked"];
    }
    
    if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if ([camera focusMode] == AVCaptureFocusModeAutoFocus)
        {
            currentIndex = [supportedModes count];
        }

        [supportedModes addObject:@"Auto"];
    }
    
    if ([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
    {
        if ([camera focusMode] == AVCaptureFocusModeContinuousAutoFocus)
        {
            currentIndex = [supportedModes count];
        }
        
        [supportedModes addObject:@"Continuous"];
    }
    
    if ([supportedModes count] == 0)
    {
        self.focusModeSegment.hidden = YES;
        self.focusModeLabel.hidden   = YES;
        
        UIAlertView*    alert = [[UIAlertView alloc] initWithTitle:@"No Focus Modes" 
                                                           message:@"Camera focus can't be controlled."
                                                          delegate:self
                                                 cancelButtonTitle:@"Close"
                                                 otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    else if ([supportedModes count] == 1)
    {
        self.focusModeSegment.hidden = YES;
        self.focusModeLabel.hidden   = YES;
        
        NSString*       message = [NSString stringWithFormat:@"There's only one camera focus mode: %@.", 
                                   [supportedModes lastObject]];
        
        UIAlertView*    alert = [[UIAlertView alloc] initWithTitle:@"One Focus Mode"
                                                           message:message
                                                          delegate:self
                                                 cancelButtonTitle:@"Close"
                                                 otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    else if ([supportedModes count] == 2)
    {
        [self.focusModeSegment removeSegmentAtIndex:0 animated:NO];
        for (int i = 0; i < [supportedModes count]; i++)
        {
            [self.focusModeSegment setTitle:[supportedModes objectAtIndex:i] forSegmentAtIndex:i];            
        }
    }
    
    [self.focusModeSegment setSelectedSegmentIndex:currentIndex];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    couponSpecification = [[Common objectWithFile:@"Coupon.json"] retain];
    active              = YES;
    imageCount          = 5;    // Default of stepper.
    
    self.versionLabel.text = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    
	if (self.captureSession == nil)
    {
		[self setupSession];
        
        // Create video preview layer and add it to the UI
        AVCaptureVideoPreviewLayer* newCaptureVideoPreviewLayer;
        CALayer*                    viewLayer;
        
        newCaptureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        viewLayer = [self.view layer];
        [viewLayer setMasksToBounds:YES];
        
        CGRect bounds = [self.view bounds];
        [newCaptureVideoPreviewLayer setFrame:bounds];
        
        [newCaptureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        
        [viewLayer insertSublayer:newCaptureVideoPreviewLayer below:[[viewLayer sublayers] objectAtIndex:0]];

        [self setCaptureVideoPreviewLayer:newCaptureVideoPreviewLayer];
        [newCaptureVideoPreviewLayer release];
        
        self.crossImageViews = [NSMutableArray array];

        for (int i = 0; i < 3; i++)
        {
            UIImageView*    crossImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Cross"]];
            
            [self.view addSubview:crossImageView];
            crossImageView.hidden = YES;
            
            [self.crossImageViews addObject:crossImageView];
        }
        
        self.squareImageViews = [NSMutableArray array];
                
        for (int i = 0; i < [[couponSpecification objectForKey:@"fields"] count]; i++)
        {
            UIImageView*    squareImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Square"]];
            
            [self.view addSubview:squareImageView];
            squareImageView.hidden = YES;
            
            [self.squareImageViews addObject:squareImageView];
        }

        UIImageView*    logoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo"]];
        [self.view addSubview:logoImageView];
        logoImageView.center = CGPointMake(768 / 2, 1024 - 980);
        
        // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
        {
            [self.captureSession startRunning];
        });
        
        [self setupFucusMode];
	}
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller
{
    [self.flipsidePopoverController dismissPopoverAnimated:YES];
}


- (void)dealloc
{
    [_flipsidePopoverController release];
    [couponSpecification        release];
    
    [super dealloc];
}


- (IBAction)showInfo:(id)sender
{
    if (!self.flipsidePopoverController)
    {
        FlipsideViewController *controller = [[[FlipsideViewController alloc] initWithNibName:@"FlipsideViewController" bundle:nil] autorelease];
        controller.delegate = self;
        
        self.flipsidePopoverController = [[[UIPopoverController alloc] initWithContentViewController:controller] autorelease];
    }
    if ([self.flipsidePopoverController isPopoverVisible])
    {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
    } 
    else
    {
        [self.flipsidePopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}


- (IBAction)stepAction:(id)sender
{
    UIStepper*  stepper = sender;
    
    self.imageCountLabel.text = [NSString stringWithFormat:@"%d", (int)round(stepper.value)];
    imageCount = (int)round(stepper.value);
}


- (IBAction)focusModeAction:(id)sender
{
    NSString*   mode = [self.focusModeSegment titleForSegmentAtIndex:[self.focusModeSegment selectedSegmentIndex]];
    
    if ([mode isEqualToString:@"Locked"])
    {
        [camera setFocusMode:AVCaptureFocusModeLocked];
    }
    else if ([mode isEqualToString:@"Auto"])
    {
        [camera setFocusMode:AVCaptureFocusModeAutoFocus];
    }
    else
    {
        [camera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
}

@end
