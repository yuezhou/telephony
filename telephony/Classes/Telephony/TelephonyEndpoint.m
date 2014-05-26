//
//  TelephonyEndpoint.m
//  rpmPadController
//
//  Created by Alejandro Orellana on 6/8/09.
//  Copyright 2009 Savant Systems, LLC. All rights reserved.
//

#import "TelephonyEndpoint.h"
//#import "Telephony.h"
#import <pjsua-lib/pjsua.h>

#import "NSString+PJSIP.h"
#import "TelephonyEndpointAccount.h"
#import "TelephonyEndpointCall.h"


const NSInteger kAKTelephoneInvalidIdentifier = PJSUA_INVALID_ID;
const NSInteger kAKTelephoneNameserversMax = 4;
const NSInteger kAKTelephoneInvalidBLFSubscriptionIndex = PJSUA_INVALID_ID;

NSString * const AKTelephoneUserAgentDidFinishStartingNotification
  = @"AKTelephoneUserAgentDidFinishStarting";
NSString * const AKTelephoneUserAgentDidFinishStoppingNotification
  = @"AKTelephoneUserAgentDidFinishStopping";
NSString * const AKTelephoneDidDetectNATNotification
  = @"AKTelephoneDidDetectNAT";

// Generic config defaults.
NSString * const kAKTelephoneDefaultOutboundProxyHost = @"";
const NSInteger kAKTelephoneDefaultOutboundProxyPort = 5060;
NSString * const kAKTelephoneDefaultSTUNServerHost = @"";
const NSInteger kAKTelephoneDefaultSTUNServerPort = 3478;
NSString * const kAKTelephoneDefaultLogFileName = nil;
const NSInteger kAKTelephoneDefaultLogLevel = 4;
const NSInteger kAKTelephoneDefaultConsoleLogLevel = 4;
const BOOL kAKTelephoneDefaultDetectsVoiceActivity = YES;
const BOOL kAKTelephoneDefaultUsesICE = NO;
const NSInteger kAKTelephoneDefaultTransportPort = 0;  // 0 for any available port.
NSString * const kAKTelephoneDefaultTransportPublicHost = nil;

static TelephonyEndpoint *sharedTelephone = nil;

enum {
  kAKRingbackFrequency1  = 440,
  kAKRingbackFrequency2  = 480,
  kAKRingbackOnDuration  = 2000,
  kAKRingbackOffDuration = 4000,
  kAKRingbackCount       = 1,
  kAKRingbackInterval    = 4000
};


void rpm_log_func(int level, const char *data, int len);

@interface TelephonyEndpoint ()


// Create and start SIP user agent. Supposed to be run on the secondary thread.
- (void)ak_startUserAgent;

// Stop and destroy SIP user agent. Supposed to be run on the secondary thread.
- (void)ak_stopUserAgent;
//kill the stack, called from when we enter background
- (void)_killUserAgent;

@end


@implementation TelephonyEndpoint

#define THIS_FILE "TelephonyEndpoint.m"

- (id <AKTelephoneDelegate>)delegate {
  return self.delegate;
}

- (void)setDelegate:(id <AKTelephoneDelegate>)aDelegate {
  if (self.delegate == aDelegate)
    return;
  
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  
  if (self.delegate != nil)
    [notificationCenter removeObserver:self.delegate name:nil object:self];
  
  if (aDelegate != nil) {
    if ([aDelegate respondsToSelector:@selector(telephoneUserAgentDidFinishStarting:)])
      [notificationCenter addObserver:aDelegate
                             selector:@selector(telephoneUserAgentDidFinishStarting:)
                                 name:AKTelephoneUserAgentDidFinishStartingNotification
                               object:self];
    
    if ([aDelegate respondsToSelector:@selector(telephoneUserAgentDidFinishStopping:)])
      [notificationCenter addObserver:aDelegate
                             selector:@selector(telephoneUserAgentDidFinishStopping:)
                                 name:AKTelephoneUserAgentDidFinishStoppingNotification
                               object:self];
    
    if ([aDelegate respondsToSelector:@selector(telephoneDidDetectNAT:)])
      [notificationCenter addObserver:aDelegate
                             selector:@selector(telephoneDidDetectNAT:)
                                 name:AKTelephoneDidDetectNATNotification
                               object:self];
  }
  
  self.delegate = aDelegate;
}

- (BOOL)userAgentStarted {
  return ([self userAgentState] == kAKTelephoneUserAgentStarted) ? YES : NO;
}

- (NSUInteger)activeCallsCount {
  return pjsua_call_get_count();
}

//- (AKTelephoneCallData *)callData {
//  return callData_;
//}

//- (NSArray *)nameservers {
//  return [self.nameservers copy];
//}
//
//- (void)setNameservers:(NSArray *)newNameservers {
//  if (self.nameservers != newNameservers) {
//    
//    if ([newNameservers count] > kAKTelephoneNameserversMax) {
//      self.nameservers = [newNameservers subarrayWithRange:
//                      NSMakeRange(0, kAKTelephoneNameserversMax)];
//    } else {
//      self.nameservers = [newNameservers copy];
//    }
//  }
//}
//
//- (NSUInteger)outboundProxyPort {
//  return self.outboundProxyPort;
//}
//
//- (void)setOutboundProxyPort:(NSUInteger)port {
//  if (port > 0 && port < 65535)
//    self.outboundProxyPort = port;
//  else
//    self.outboundProxyPort = kAKTelephoneDefaultOutboundProxyPort;
//}
//
//- (NSUInteger)STUNServerPort {
//  return self.STUNServerPort;
//}
//
//- (void)setSTUNServerPort:(NSUInteger)port {
//  if (port > 0 && port < 65535)
//    self.STUNServerPort = port;
//  else
//    self.STUNServerPort = kAKTelephoneDefaultSTUNServerPort;
//}
//
//- (NSString *)logFileName {
//  return [self.logFileName copy];
//}
//
//- (void)setLogFileName:(NSString *)pathToFile {
//  if (self.logFileName != pathToFile) {
//    if ([pathToFile length] > 0) {
//      self.logFileName = [pathToFile copy];
//    } else {
//      self.logFileName = kAKTelephoneDefaultLogFileName;
//    }
//  }
//}
//
//- (NSUInteger)transportPort {
//  return self.transportPort;
//}
//
//- (void)setTransportPort:(NSUInteger)port {
//  if (port > 0 && port < 65535)
//    self.transportPort = port;
//  else
//    self.transportPort = kAKTelephoneDefaultTransportPort;
//}


#pragma mark Telephone singleton instance

+ (TelephonyEndpoint *)sharedTelephone {
  @synchronized(self) {
    if (sharedTelephone == nil)
      [[self alloc] init];  // Assignment not done here.
  }
  
  return sharedTelephone;
}

+ (id)allocWithZone:(NSZone *)zone {
  @synchronized(self) {
    if (sharedTelephone == nil) {
      sharedTelephone = [super allocWithZone:zone];
      return sharedTelephone;  // Assignment and return on first allocation.
    }
  }
  
  return nil;  // On subsequent allocation attempts return nil.
}
//--------------------------------------------------
// Commented out by Nick. Overriding these methods 
// in this manner is not good practice.
//--------------------------------------------------
/*
- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (id)retain {
  return self;
}

- (NSUInteger)retainCount {
  return UINT_MAX;  // Denotes an object that cannot be released.
}

- (void)release {
  // Do nothing.
}

- (id)autorelease {
  return self;
}
*/

#pragma mark -

- (id)initWithDelegate:(id)aDelegate {
  self = [super init];
  if (self == nil)
    return nil;
  
//  [self.Delegate:aDelegate];
  self.accounts = [[NSMutableArray alloc] init];
  self.detectedNATType=kAKNATTypeUnknown;
  self.pjsuaLock = [[NSLock alloc] init];
  
  self.outboundProxyHost=kAKTelephoneDefaultOutboundProxyHost;
  self.outboundProxyPort=kAKTelephoneDefaultOutboundProxyPort;
  self.STUNServerHost=kAKTelephoneDefaultSTUNServerHost;
  self.STUNServerPort=kAKTelephoneDefaultSTUNServerPort;
  self.logFileName=kAKTelephoneDefaultLogFileName;
  self.logLevel=kAKTelephoneDefaultLogLevel;
  self.consoleLogLevel=kAKTelephoneDefaultConsoleLogLevel;
  self.detectsVoiceActivity=kAKTelephoneDefaultDetectsVoiceActivity;
  self.usesICE=kAKTelephoneDefaultUsesICE;
  self.transportPort=kAKTelephoneDefaultTransportPort;
  self.transportPublicHost=kAKTelephoneDefaultTransportPublicHost;
  
  self.ringbackSlot=kAKTelephoneInvalidIdentifier;
  
  return self;
}

- (id)init {
  return [self initWithDelegate:nil];
}

#pragma mark - sip logging function wrapper
void rpm_log_func(int level, const char *data, int len)
{
//    char *buff=malloc(len +1);
//    memcpy(buff,data,len);
//    buff[len]='\0'; // NULL terminated
//
//    if([[NSUserDefaults standardUserDefaults] boolForKey:kPreferencesConsoleLogs])
//    {
//        printf("%s",&buff[1]);
//    }
//    else
//    {
//        [rpmLogEvent log:[NSString  stringWithCString:&buff[1] encoding:NSUTF8StringEncoding] object:nil  priority:RPMIOSLOG_SEVERITY_INFO];
//    }
//
//    free(buff);
}

#pragma mark -

- (void)startUserAgent {
  // Do nothing if it's already started or being started.
  if ([self userAgentState] > kAKTelephoneUserAgentStopped)
    return;
  
  [[self pjsuaLock] lock];
  
  self.userAgentState=kAKTelephoneUserAgentStarting;
  
  // Create PJSUA on the main thread to make all subsequent calls from the main
  // thread.
  pj_status_t status = pjsua_create();
  if (status != PJ_SUCCESS) {
    NSLog(@"Error creating PJSUA");
    self.userAgentState=kAKTelephoneUserAgentStopped;
    [[self pjsuaLock] unlock];
    return;
  }
  
  [[self pjsuaLock] unlock];
  
  [self performSelectorInBackground:@selector(ak_startUserAgent)
                         withObject:nil];
    
}

// This method is supposed to run in the secondary thread.
- (void)ak_startUserAgent 
{
    [[self pjsuaLock] lock];

    self.userAgentState=kAKTelephoneUserAgentStarting;

    pj_status_t status;

    pj_thread_desc aPJThreadDesc;
    if (!pj_thread_is_registered())
    {
        pj_thread_t *pjThread;
        status = pj_thread_register(NULL, aPJThreadDesc, &pjThread);
        if (status != PJ_SUCCESS)
          NSLog(@"Error registering thread at PJSUA");
    }

    // Create pool for PJSUA.
    pj_pool_t *aPJPool;
    aPJPool = pjsua_pool_create("telephone-pjsua", 1000, 1000);
    self.pjPool=aPJPool;

    pjsua_config userAgentConfig;
    pjsua_logging_config loggingConfig;
    pjsua_media_config mediaConfig;
    pjsua_transport_config transportConfig;

    pjsua_config_default(&userAgentConfig);
    pjsua_logging_config_default(&loggingConfig);
    pjsua_media_config_default(&mediaConfig);
    pjsua_transport_config_default(&transportConfig);

    userAgentConfig.max_calls = 8;

    if ([[self nameservers] count] > 0)
    {
        userAgentConfig.nameserver_count = [[self nameservers] count];
        for (NSUInteger i = 0; i < [[self nameservers] count]; ++i)
          userAgentConfig.nameserver[i] = [[[self nameservers] objectAtIndex:i] pjString];
    }

    if ([[self outboundProxyHost] length] > 0)
    {
        userAgentConfig.outbound_proxy_cnt = 1;

        if ([self outboundProxyPort] == kAKTelephoneDefaultOutboundProxyPort) 
        {
          userAgentConfig.outbound_proxy[0] = [[NSString stringWithFormat:@"sip:%@",
                                                [self outboundProxyHost]]
                                               pjString];
        } 
        else 
        {
          userAgentConfig.outbound_proxy[0] = [[NSString stringWithFormat:@"sip:%@:%u",
                                                [self outboundProxyHost],
                                                [self outboundProxyPort]]
                                               pjString];
        }
    }


    if ([[self STUNServerHost] length] > 0) 
    {
        userAgentConfig.stun_host = [[NSString stringWithFormat:@"%@:%u",
                                      [self STUNServerHost], [self STUNServerPort]]
                                     pjString];
    }

    userAgentConfig.user_agent = [[self userAgentString] pjString];

    if ([[self logFileName] length] > 0) 
    {
        loggingConfig.log_filename
          = [[[self logFileName] stringByExpandingTildeInPath]
             pjString];
    }

    loggingConfig.level         = 5;//[self logLevel];
    loggingConfig.console_level = 5;//[self consoleLogLevel];
    loggingConfig.cb            = rpm_log_func;
    
    mediaConfig.no_vad = ![self detectsVoiceActivity];
    mediaConfig.enable_ice = [self usesICE];
    mediaConfig.snd_auto_close_time = 1;
    transportConfig.port = [self transportPort];

    transportConfig.public_addr = [@"10.5.225.17" pjString];
    //transportConfig.bound_addr  = [[rpmDeviceUtils getMyIPAddress] pjString];

//    userAgentConfig.cb.on_incoming_call    = AKIncomingCallReceived;
//    userAgentConfig.cb.on_call_media_state = AKCallMediaStateChanged;
//    userAgentConfig.cb.on_call_state       = AKCallStateChanged; 
////    userAgentConfig.cb.on_reg_state        = AKTelephoneAccountRegistrationStateChanged;
//    userAgentConfig.cb.on_reg_state2       = AKTelephoneAccountRegistrationStateChanged;
//    userAgentConfig.cb.on_nat_detect       = AKTelephoneDetectedNAT;
//    userAgentConfig.cb.on_mwi_info         = AKMWINotifyReceived;
//	userAgentConfig.cb.on_sla_info         = AKTelephoneSLANotify;
//	userAgentConfig.cb.on_call_tsx_state   = AKCallTsxStateChanged;
    
	// Initialize PJSUA.
    status = pjsua_init(&userAgentConfig, &loggingConfig, &mediaConfig);
    if (status != PJ_SUCCESS) 
    {
        NSLog(@"Error initializing PJSUA");
        self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }

    unsigned char decor =pj_log_get_decor();
    
    pj_log_set_decor(decor | PJ_LOG_HAS_YEAR |PJ_LOG_HAS_MONTH|PJ_LOG_HAS_DAY_OF_MON);
    
    // Create ringback tones.
    unsigned i, samplesPerFrame;
    pjmedia_tone_desc tone[kAKRingbackCount];
    pj_str_t name;

    samplesPerFrame = mediaConfig.audio_frame_ptime *
    mediaConfig.clock_rate *
    mediaConfig.channel_count / 1000;

    name = pj_str("ringback");
    pjmedia_port *aRingbackPort;
    status = pjmedia_tonegen_create2([self pjPool], &name,
                                   mediaConfig.clock_rate,
                                   mediaConfig.channel_count,
                                   samplesPerFrame, 16, PJMEDIA_TONEGEN_LOOP,
                                   &aRingbackPort);
    if (status != PJ_SUCCESS) 
    {
        NSLog(@"Error creating ringback tones");
        pjsua_perror(THIS_FILE, "creating ringback tones error", status);
        self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }

    self.ringbackPort=aRingbackPort;

    pj_bzero(&tone, sizeof(tone));
    for (i = 0; i < kAKRingbackCount; ++i) 
    {
        tone[i].freq1    = kAKRingbackFrequency1;
        tone[i].freq2    = kAKRingbackFrequency2;
        tone[i].on_msec  = kAKRingbackOnDuration;
        tone[i].off_msec = kAKRingbackOffDuration;
    }
    tone[kAKRingbackCount - 1].off_msec = kAKRingbackInterval;

    pjmedia_tonegen_play([self ringbackPort], kAKRingbackCount, tone, PJMEDIA_TONEGEN_LOOP);

    NSInteger aRingbackSlot;
    status = pjsua_conf_add_port([self pjPool], [self ringbackPort], &aRingbackSlot);
    if (status != PJ_SUCCESS) 
    {
        NSLog(@"Error adding media port for ringback tones");
        pjsua_perror(THIS_FILE, "adding media port error", status);
        self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }

    self.ringbackSlot=aRingbackSlot;

    // Add UDP transport.
    pjsua_transport_id transportIdentifier;
    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transportConfig,
                                  &transportIdentifier);
    if (status != PJ_SUCCESS)
    {
        NSLog(@"Error creating UDP transport");
        pjsua_perror(THIS_FILE, "pjsua_udp_transport_create error", status);
        self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }


    // Add TCP transport. Don't return, just leave a log message on error.
    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &transportConfig, NULL);
    if (status != PJ_SUCCESS)
    {
        NSLog(@"Error creating TCP transport");
        pjsua_perror(THIS_FILE, "pjsua_tcp_transport_create error", status);
       self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }
    
    // Get transport port chosen by PJSUA.
    if ([self transportPort] == 0) 
    {
        pjsua_transport_info transportInfo;
        status = pjsua_transport_get_info(transportIdentifier, &transportInfo);
        if (status != PJ_SUCCESS)
            NSLog(@"Error getting transport info");
        
        self.transportPort=transportInfo.local_name.port;
        
        //. chosen port back to transportConfig to add TCP transport below.
        transportConfig.port = [self transportPort];
    }
    
    // Start PJSUA.
    status = pjsua_start();
    if (status != PJ_SUCCESS) 
    {
        NSLog(@"Error starting PJSUA");
       self.userAgentFailureStatus=status;
        [self stopUserAgent];
        [[self pjsuaLock] unlock];
        return;
    }

    self.userAgentState=kAKTelephoneUserAgentStarted;

    //NSLog(@"start_userAgent  : ct=%@ mt=%@", [NSThread currentThread], [NSThread mainThread]);

    NSNotification *notification
        = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStartingNotification
                                  object:self];

    [[NSNotificationCenter defaultCenter]
                performSelectorOnMainThread:@selector(postNotification:)
                withObject:notification
                waitUntilDone:NO];

    [[self pjsuaLock] unlock];
}

- (void)stopUserAgent {
  // If there was an error while starting, post a notification from here.
  if ([self userAgentState] == kAKTelephoneUserAgentStarting) {
    NSNotification *notification
    = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStartingNotification
                                    object:self];
    
    [[NSNotificationCenter defaultCenter]
     performSelectorOnMainThread:@selector(postNotification:)
                      withObject:notification
                   waitUntilDone:NO];
  }
  
  [self performSelectorInBackground:@selector(ak_stopUserAgent)
                         withObject:nil];
}

- (void)ak_stopUserAgent {
  
  pj_status_t status;
  pj_thread_desc aPJThreadDesc;
  
  if (!pj_thread_is_registered()) {
    pj_thread_t *pjThread;
    pj_status_t status = pj_thread_register(NULL, aPJThreadDesc, &pjThread);
    
    if (status != PJ_SUCCESS)
      NSLog(@"Error registering thread at PJSUA");
  }
  
  [[self pjsuaLock] lock];
  
  self.userAgentState=kAKTelephoneUserAgentStopped;
  
  // Explicitly remove all accounts.
  [[self accounts] removeAllObjects];
  
  // Close ringback port.
  if ([self ringbackPort] != NULL &&
      [self ringbackSlot] != kAKTelephoneInvalidIdentifier)
  {
    pjsua_conf_remove_port([self ringbackSlot]);
    self.ringbackSlot=kAKTelephoneInvalidIdentifier;
    pjmedia_port_destroy([self ringbackPort]);
    self.ringbackPort=NULL;
  }
  
  if ([self pjPool] != NULL) {
    pj_pool_release([self pjPool]);
    self.pjPool=NULL;
  }
  
  // Destroy PJSUA.
  status = pjsua_destroy();
  
  if (status != PJ_SUCCESS)
    NSLog(@"Error stopping SIP user agent");
  
  NSNotification *notification
  = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStoppingNotification
                                  object:self];
  
  [[NSNotificationCenter defaultCenter]
   performSelectorOnMainThread:@selector(postNotification:)
                    withObject:notification
                 waitUntilDone:NO];
  
  [[self pjsuaLock] unlock];
}

- (void)killUserAgent 
{
    // If there was an error while starting, post a notification from here.
    if ([self userAgentState] == kAKTelephoneUserAgentStarting) {
        NSNotification *notification
        = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStartingNotification
                                        object:self];
        
        [[NSNotificationCenter defaultCenter]
         performSelectorOnMainThread:@selector(postNotification:)
         withObject:notification
         waitUntilDone:NO];
    }
    
    PJ_LOG(3, (THIS_FILE, "killUserAgent"));
    
    
    [self _killUserAgent];
    
}

- (void)_killUserAgent 
{
    PJ_LOG(3, (THIS_FILE, "_killUserAgent"));
    pj_status_t status;
    pj_thread_desc aPJThreadDesc;
    
    if (!pj_thread_is_registered()) {
        pj_thread_t *pjThread;
        pj_status_t status = pj_thread_register(NULL, aPJThreadDesc, &pjThread);
        
        if (status != PJ_SUCCESS)
            NSLog(@"Error registering thread at PJSUA");
    }
    
    [[self pjsuaLock] lock];
    
    self.userAgentState=kAKTelephoneUserAgentStopped;
    
    // Explicitly remove all accounts.
    [[self accounts] removeAllObjects];
    
    // Close ringback port.
    if ([self ringbackPort] != NULL &&
        [self ringbackSlot] != kAKTelephoneInvalidIdentifier)
    {
        pjsua_conf_remove_port([self ringbackSlot]);
        self.ringbackSlot=kAKTelephoneInvalidIdentifier;
        pjmedia_port_destroy([self ringbackPort]);
        self.ringbackPort=NULL;
    }
    
    if ([self pjPool] != NULL) {
        pj_pool_release([self pjPool]);
        self.pjPool=NULL;
    }
    
    // Destroy PJSUA.
    status = pjsua_destroy();
    
    if (status != PJ_SUCCESS)
        NSLog(@"Error stopping SIP user agent");
        
    [[self pjsuaLock] unlock];
    //NSLog(@"pjsua destroyed..." );
}

-(void)telephonyEndpointSLAInitialization:(TelephonyEndpointAccount *)anAccount
{
    
}
- (BOOL)addAccount:(TelephonyEndpointAccount *)anAccount
      withPassword:(NSString *)aPassword  andSavantPhoneService:(BOOL)phoneService
{
  
  if ([[self delegate] respondsToSelector:@selector(telephoneShouldAddAccount:)])
    if (![[self delegate] telephoneShouldAddAccount:anAccount])
      return NO;
  
  pjsua_acc_config accountConfig;
  pjsua_acc_config_default(&accountConfig);
  NSString *transport;
  if(phoneService)
  {
      transport=@";transport=tcp";
  }
  else 
  {
      transport=@";transport=udp";
  }

  NSString *fullSIPURL = [NSString stringWithFormat:@"%@ <sip:%@%@>",
                           [anAccount fullName], [anAccount SIPAddress], transport];  
  accountConfig.id = [fullSIPURL pjString];
//  if ([anAccount isRegistrarNeeded])
  {
    NSString *registerURI = [NSString stringWithFormat:@"sip:%@%@",
                             [anAccount registrar], transport];
    accountConfig.reg_uri = [registerURI pjString];
    
    accountConfig.cred_count = 1;
    accountConfig.cred_info[0].realm = pj_str("*");
    accountConfig.cred_info[0].scheme = pj_str("digest");
    accountConfig.cred_info[0].username = [[anAccount username] pjString]; //[[NSString stringWithFormat:@"%@@imsdemo.com",[anAccount username]] pjString]; //
    accountConfig.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    accountConfig.cred_info[0].data = [aPassword pjString];
    
    accountConfig.ka_interval=0;
    if ([[anAccount proxyHost] length] > 0) {
      accountConfig.proxy_cnt = 1;
      
      if (anAccount.proxyPort == kAKDefaultSIPProxyPort)
        accountConfig.proxy[0] = [[NSString stringWithFormat:@"sip:%@",
                                   [anAccount proxyHost]] pjString];
      else
        accountConfig.proxy[0] = [[NSString stringWithFormat:@"sip:%@:%u",
                                   [anAccount proxyHost], [anAccount proxyPort]]
                                  pjString];
    }
    
    accountConfig.reg_timeout = [anAccount reregistrationTime];
    
    if ([self usesICE] && [[self STUNServerHost] length] > 0)
      accountConfig.allow_contact_rewrite = PJ_TRUE;
    else
      accountConfig.allow_contact_rewrite = PJ_FALSE;
	//accountConfig.mwi_enabled = PJ_TRUE;

      //SLA Initialization
//      for (NSInteger i = 1; i < kTelephonyMaxNumberOfSharedLines; i++)
//      {
//          if([anAccount lineEnabled:i] && [anAccount getLineID:i])
//          {
//              accountConfig.line[i] = [[NSString stringWithFormat:@"<sip:%@@%@;transport=tcp>",[anAccount getLineID:i], [anAccount registrar]] pjString];
//              accountConfig.sla_line_enabled[i] = PJ_TRUE;
//          }
//      }

  }
//  else 
//  {
//    //No registrar this is to support diret IP dialing without registration
//    // we have to create an userless acount, thus all. at this point
//  }

  // AOB: we only allow 1 account ! so lets check here before
  // this is kind of a workaround since we have a crash in pjsua_acc_add
  // i dont think the crash is the root cause here. SCR22762
  if(pjsua_acc_get_count())
  {
//      [rpmLogEvent log:@"We already have an account!!!" object:[NSNumber numberWithInt:pjsua_acc_get_count()]];
      return NO;
  }
       
  pjsua_acc_id accountIdentifier;
  pj_status_t status = pjsua_acc_add(&accountConfig, PJ_FALSE,
                                     &accountIdentifier);
  if (status != PJ_SUCCESS) {
    NSLog(@"Error adding account %@ with status %d", anAccount, status);
    return NO;
  }
  
  anAccount.identifier=accountIdentifier;
  
  [[self accounts] addObject:anAccount];
  
//  [anAccount.Online:YES];
  
  return YES;
}

- (BOOL)removeAccount:(TelephonyEndpointAccount *)anAccount {
  if (![self userAgentStarted] ||
      [anAccount identifier] == kAKTelephoneInvalidIdentifier)
    return NO;
  
  [[NSNotificationCenter defaultCenter]
   postNotificationName:AKTelephoneAccountWillRemoveNotification
                 object:anAccount];
  
  // Explicitly remove all calls.
  [[anAccount calls] removeAllObjects];
  
  pj_status_t status = pjsua_acc_del([anAccount identifier]);
  if (status != PJ_SUCCESS)
    return NO;
  
  [[self accounts] removeObject:anAccount];
  anAccount.identifier=kAKTelephoneInvalidIdentifier;
  
  return YES;
}

- (TelephonyEndpointAccount *)accountByIdentifier:(NSInteger)anIdentifier {
  for (TelephonyEndpointAccount *anAccount in [[self accounts] copy])
    if ([anAccount identifier] == anIdentifier)
      return anAccount;
  
  return nil;
}

- (TelephonyEndpointCall *)telephoneCallByIdentifier:(NSInteger)anIdentifier {
  for (TelephonyEndpointAccount *anAccount in [[self accounts] copy])
    for (TelephonyEndpointCall *aCall in [[anAccount calls] copy])
      if ([aCall identifier] == anIdentifier)
        return aCall;
  
  return nil;
}

- (void)hangUpAllCalls {
  pjsua_call_hangup_all();
}

- (BOOL)setSoundInputDevice:(NSInteger)input
          soundOutputDevice:(NSInteger)output {
  if (![self userAgentStarted])
    return NO;
  
  pj_status_t status = pjsua_set_snd_dev(input, output);
  
  return (status == PJ_SUCCESS) ? YES : NO;
}

- (BOOL)stopSound {
  if (![self userAgentStarted])
    return NO;
  
  pj_status_t status = pjsua_set_null_snd_dev();
  
  return (status == PJ_SUCCESS) ? YES : NO;
}

// This method will leave application silent.
//.SoundInputDevice:soundOutputDevice: must be called explicitly after calling
// this method to. sound IO.
// Usually application controller is responsible of sending
//.SoundInputDevice:soundOutputDevice: to. sound IO after this method is called.
- (void)updateAudioDevices {
  if (![self userAgentStarted])
    return;
  
  // Stop sound device and disconnect it from the conference.
  pjsua_set_null_snd_dev();
  
  // Reinit sound device.
  pjmedia_snd_deinit();
  pjmedia_snd_init(pjsua_get_pool_factory());
}

- (NSString *)stringForSIPResponseCode:(NSInteger)responseCode {
  NSString *theString = nil;
  
  switch (responseCode) {
        // Provisional 1xx.
      case PJSIP_SC_TRYING:
        theString = @"Trying";
        break;
      case PJSIP_SC_RINGING:
        theString = @"Ringing";
        break;
      case PJSIP_SC_CALL_BEING_FORWARDED:
        theString = @"Call Is Being Forwarded";
        break;
      case PJSIP_SC_QUEUED:
        theString = @"Queued";
        break;
      case PJSIP_SC_PROGRESS:
        theString = @"Session Progress";
        break;
        
        // Successful 2xx.
      case PJSIP_SC_OK:
        theString = @"OK";
        break;
      case PJSIP_SC_ACCEPTED:
        theString = @"Accepted";
        break;
        
        // Redirection 3xx.
      case PJSIP_SC_MULTIPLE_CHOICES:
        theString = @"Multiple Choices";
        break;
      case PJSIP_SC_MOVED_PERMANENTLY:
        theString = @"Moved Permanently";
        break;
      case PJSIP_SC_MOVED_TEMPORARILY:
        theString = @"Moved Temporarily";
        break;
      case PJSIP_SC_USE_PROXY:
        theString = @"Use Proxy";
        break;
      case PJSIP_SC_ALTERNATIVE_SERVICE:
        theString = @"Alternative Service";
        break;
        
        // Request Failure 4xx.
      case PJSIP_SC_BAD_REQUEST:
        theString = @"Bad Request";
        break;
      case PJSIP_SC_UNAUTHORIZED:
        theString = @"Unauthorized";
        break;
      case PJSIP_SC_PAYMENT_REQUIRED:
        theString = @"Payment Required";
        break;
      case PJSIP_SC_FORBIDDEN:
        theString = @"Forbidden";
        break;
      case PJSIP_SC_NOT_FOUND:
        theString = @"Not Found";
        break;
      case PJSIP_SC_METHOD_NOT_ALLOWED:
        theString = @"Method Not Allowed";
        break;
      case PJSIP_SC_NOT_ACCEPTABLE:
        theString = @"Not Acceptable";
        break;
      case PJSIP_SC_PROXY_AUTHENTICATION_REQUIRED:
        theString = @"Proxy Authentication Required";
        break;
      case PJSIP_SC_REQUEST_TIMEOUT:
        theString = @"Request Timeout";
        break;
      case PJSIP_SC_GONE:
        theString = @"Gone";
        break;
      case PJSIP_SC_REQUEST_ENTITY_TOO_LARGE:
        theString = @"Request Entity Too Large";
        break;
      case PJSIP_SC_REQUEST_URI_TOO_LONG:
        theString = @"Request-URI Too Long";
        break;
      case PJSIP_SC_UNSUPPORTED_MEDIA_TYPE:
        theString = @"Unsupported Media Type";
        break;
      case PJSIP_SC_UNSUPPORTED_URI_SCHEME:
        theString = @"Unsupported URI Scheme";
        break;
      case PJSIP_SC_BAD_EXTENSION:
        theString = @"Bad Extension";
        break;
      case PJSIP_SC_EXTENSION_REQUIRED:
        theString = @"Extension Required";
        break;
      case PJSIP_SC_SESSION_TIMER_TOO_SMALL:
        theString = @"Session Timer Too Small";
        break;
      case PJSIP_SC_INTERVAL_TOO_BRIEF:
        theString = @"Interval Too Brief";
        break;
      case PJSIP_SC_TEMPORARILY_UNAVAILABLE:
        theString = @"Temporarily Unavailable";
        break;
      case PJSIP_SC_CALL_TSX_DOES_NOT_EXIST:
        theString = @"Call/Transaction Does Not Exist";
        break;
      case PJSIP_SC_LOOP_DETECTED:
        theString = @"Loop Detected";
        break;
      case PJSIP_SC_TOO_MANY_HOPS:
        theString = @"Too Many Hops";
        break;
      case PJSIP_SC_ADDRESS_INCOMPLETE:
        theString = @"Address Incomplete";
        break;
      case PJSIP_AC_AMBIGUOUS:
        theString = @"Ambiguous";
        break;
      case PJSIP_SC_BUSY_HERE:
        theString = @"Busy Here";
        break;
      case PJSIP_SC_REQUEST_TERMINATED:
        theString = @"Request Terminated";
        break;
      case PJSIP_SC_NOT_ACCEPTABLE_HERE:
        theString = @"Not Acceptable Here";
        break;
      case PJSIP_SC_BAD_EVENT:
        theString = @"Bad Event";
        break;
      case PJSIP_SC_REQUEST_UPDATED:
        theString = @"Request Updated";
        break;
      case PJSIP_SC_REQUEST_PENDING:
        theString = @"Request Pending";
        break;
      case PJSIP_SC_UNDECIPHERABLE:
        theString = @"Undecipherable";
        break;
        
        // Server Failure 5xx.
      case PJSIP_SC_INTERNAL_SERVER_ERROR:
        theString = @"Server Internal Error";
        break;
      case PJSIP_SC_NOT_IMPLEMENTED:
        theString = @"Not Implemented";
        break;
      case PJSIP_SC_BAD_GATEWAY:
        theString = @"Bad Gateway";
        break;
      case PJSIP_SC_SERVICE_UNAVAILABLE:
        theString = @"Service Unavailable";
        break;
      case PJSIP_SC_SERVER_TIMEOUT:
        theString = @"Server Time-out";
        break;
      case PJSIP_SC_VERSION_NOT_SUPPORTED:
        theString = @"Version Not Supported";
        break;
      case PJSIP_SC_MESSAGE_TOO_LARGE:
        theString = @"Message Too Large";
        break;
      case PJSIP_SC_PRECONDITION_FAILURE:
        theString = @"Precondition Failure";
        break;
        
        // Global Failures 6xx.
      case PJSIP_SC_BUSY_EVERYWHERE:
        theString = @"Busy Everywhere";
        break;
      case PJSIP_SC_DECLINE:
        theString = @"Decline";
        break;
      case PJSIP_SC_DOES_NOT_EXIST_ANYWHERE:
        theString = @"Does Not Exist Anywhere";
        break;
      case PJSIP_SC_NOT_ACCEPTABLE_ANYWHERE:
        theString = @"Not Acceptable";
        break;
      default:
        theString = [NSString stringWithFormat:@"Response code: %d",
                     responseCode];
        break;
  }
  
  return theString;
}

@end


void AKTelephoneDetectedNAT(const pj_stun_nat_detect_result *result) {
  
  if (result->status != PJ_SUCCESS) {
    pjsua_perror(THIS_FILE, "NAT detection failed", result->status);
    
  } else {
    PJ_LOG(4, (THIS_FILE, "NAT detected as %s", result->nat_type_name));
    
    [TelephonyEndpoint sharedTelephone].DetectedNATType=result->nat_type;
    
    NSNotification *notification
      = [NSNotification notificationWithName:AKTelephoneDidDetectNATNotification
                                      object:[TelephonyEndpoint sharedTelephone]];
    
    [[NSNotificationCenter defaultCenter]
     performSelectorOnMainThread:@selector(postNotification:)
                      withObject:notification
                   waitUntilDone:NO];
  }
}
