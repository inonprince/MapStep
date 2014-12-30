// Forked from https://github.com/sharedRoutine/MapStep

static NSTimer * _playTimer;
static BOOL wasPlayingFlag;
static BOOL shouldPlayFlag;

@interface SBMediaController : NSObject
+(id)sharedInstance;
-(BOOL)pause;
-(BOOL)isPaused;
-(BOOL)isPlaying;
-(BOOL)play;
@end

@interface NSDistributedNotificationCenter : NSNotificationCenter
+ (id)defaultCenter;
- (void)postNotificationName:(id)arg1 object:(id)arg2;
- (void)removeObserver:(id)arg1 name:(id)arg2 object:(id)arg3;
- (void)addObserver:(id)arg1 selector:(SEL)arg2 name:(id)arg3 object:(id)arg4;
@end

#define SRMediaController ((SBMediaController *)[%c(SBMediaController) sharedInstance])
#define SRPlayNotification @"com.inonio.mapstep.play.notification"
#define SRPauseNotification @"com.inonio.mapstep.pause.notification"
#define Post_Notification(name) [[NSDistributedNotificationCenter defaultCenter] postNotificationName:name object:nil]

%group MapStep
%hook MNVoiceController

-(void)speak:(id)arg1 completionBlock:(/*^block*/ id)arg2 {
	Post_Notification(SRPauseNotification); //notification to pause playing send to springboard
	%orig;
}

-(void)speechSynthesizer:(id)synthesizer didFinishSpeaking:(BOOL)finish withError:(NSError *)error {
	Post_Notification(SRPlayNotification);
	%orig;
}

-(void)dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
	%orig;
}

%end
%end

@interface SRMapStep : NSObject
-(void)notificationReceived:(NSNotification *)notification;
@end

@implementation SRMapStep

-(void)debug:(NSString *)msg {
	//NSLog(@"**** %@, should: %d, was: %d", msg, shouldPlayFlag, wasPlayingFlag);
}

-(void)notificationReceived:(NSNotification *)notification {
	if ([notification.name isEqualToString:SRPauseNotification]) {
		[self debug:@"SRPauseNotification"];
		shouldPlayFlag = false;
		if ([SRMediaController isPlaying]) {
			[self debug:@"isPlaying is true, pausing"];
			wasPlayingFlag = true;
			[SRMediaController pause];
		}
	}

	if ([notification.name isEqualToString:SRPlayNotification]) {
		[self debug:@"SRPlayNotification"];
		shouldPlayFlag = true;
		_playTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(playAudio) userInfo:nil repeats:NO ];
	}

}

-(void)playAudio {
	[self debug:@"playAudio"];
	if (wasPlayingFlag && shouldPlayFlag) {
		[self debug:@"playAudio: flags ok"];
  	if ([SRMediaController isPaused]) {
  		[self debug:@"isPaused is true, playing"];
  		wasPlayingFlag = false;
  		shouldPlayFlag = false;
			[SRMediaController play];
		}
  }
}

@end

%ctor {
	NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
	if (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]) {
		SRMapStep *mapStep = [[SRMapStep alloc] init]; //it is running all the time to receive our notifications
		[[NSDistributedNotificationCenter defaultCenter] addObserver:mapStep selector:@selector(notificationReceived:) name:nil object:nil];
	} else if (bundleID && [bundleID isEqualToString:@"com.apple.Maps"]) {
		%init(MapStep);
	}
}