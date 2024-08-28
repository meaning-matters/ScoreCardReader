#import <AVFoundation/AVFoundation.h>
#import "FlipsideViewController.h"
#import "CouponFinder.h"

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate,
                                                  CouponFinderDelegate,
                                                  AVCaptureVideoDataOutputSampleBufferDelegate,
                                                  UIAlertViewDelegate>

@property (nonatomic, retain) UIPopoverController*          flipsidePopoverController;
@property (nonatomic, retain) AVCaptureSession*             captureSession;
@property (nonatomic, retain) AVCaptureDeviceInput*         videoInput;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer*   captureVideoPreviewLayer;
@property (nonatomic, retain) NSMutableArray*               crossImageViews;
@property (nonatomic, retain) NSMutableArray*               squareImageViews;
@property (nonatomic, retain) IBOutlet UISlider*            globalCompensationSlider;
@property (nonatomic, retain) IBOutlet UISlider*            localCompensationSlider;
@property (nonatomic, retain) IBOutlet UILabel*             imageCountLabel;
@property (nonatomic, retain) IBOutlet UILabel*             globalCompensationLabel;
@property (nonatomic, retain) IBOutlet UILabel*             localCompensationLabel;
@property (nonatomic, retain) IBOutlet UILabel*             versionLabel;
@property (nonatomic, retain) IBOutlet UISegmentedControl*  focusModeSegment;
@property (nonatomic, retain) IBOutlet UILabel*             focusModeLabel;


- (IBAction)showInfo:(id)sender;

- (IBAction)stepAction:(id)sender;

- (IBAction)focusModeAction:(id)sender;

@end
