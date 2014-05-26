//
//  TelephonyEndpoint.h
//  rpmPadController
//
//  Created by Alejandro Orellana on 6/8/09.
//  Copyright 2009 Savant Systems, LLC. All rights reserved.
//

//#import <Foundation/Foundation.h>
//#import <UIKit/UIKit.h>
//#import "rpmPadControllerAppDelegate.h"
#import <pjsua-lib/pjsua.h>


extern const NSInteger kAKTelephoneInvalidIdentifier;
extern const NSInteger kAKTelephoneNameserversMax;

// Generic config defaults.
extern NSString * const kAKTelephoneDefaultOutboundProxyHost;
extern const NSInteger kAKTelephoneDefaultOutboundProxyPort;
extern NSString * const kAKTelephoneDefaultSTUNServerHost;
extern const NSInteger kAKTelephoneDefaultSTUNServerPort;
extern NSString * const kAKTelephoneDefaultLogFileName;
extern const NSInteger kAKTelephoneDefaultLogLevel;
extern const NSInteger kAKTelephoneDefaultConsoleLogLevel;
extern const BOOL kAKTelephoneDefaultDetectsVoiceActivity;
extern const BOOL kAKTelephoneDefaultUsesICE;
extern const NSInteger kAKTelephoneDefaultTransportPort;
extern NSString * const kAKTelephoneDefaultTransportPublicHost;

typedef struct _AKTelephoneCallData {
  pj_timer_entry timer;
  pj_bool_t ringbackOn;
  pj_bool_t ringbackOff;
} AKTelephoneCallData;

enum {
  kAKNATTypeUnknown        = PJ_STUN_NAT_TYPE_UNKNOWN,
  kAKNATTypeErrorUnknown   = PJ_STUN_NAT_TYPE_ERR_UNKNOWN,
  kAKNATTypeOpen           = PJ_STUN_NAT_TYPE_OPEN,
  kAKNATTypeBlocked        = PJ_STUN_NAT_TYPE_BLOCKED,
  kAKNATTypeSymmetricUDP   = PJ_STUN_NAT_TYPE_SYMMETRIC_UDP,
  kAKNATTypeFullCone       = PJ_STUN_NAT_TYPE_FULL_CONE,
  kAKNATTypeSymmetric      = PJ_STUN_NAT_TYPE_SYMMETRIC,
  kAKNATTypeRestricted     = PJ_STUN_NAT_TYPE_RESTRICTED,
  kAKNATTypePortRestricted = PJ_STUN_NAT_TYPE_PORT_RESTRICTED
};
typedef NSUInteger AKNATType;

enum {
  kAKTelephoneUserAgentStopped,
  kAKTelephoneUserAgentStarting,
  kAKTelephoneUserAgentStarted
};
typedef NSUInteger AKTelephoneUserAgentState;

@class TelephonyEndpointAccount, TelephonyEndpointCall;

@protocol AKTelephoneDelegate;

@interface TelephonyEndpoint : NSObject

@property id <AKTelephoneDelegate> delegate_;

@property NSMutableArray *accounts;
@property AKTelephoneUserAgentState userAgentState;
@property AKNATType detectedNATType;
@property NSLock *pjsuaLock;

@property NSArray *nameservers;
@property NSString *outboundProxyHost;
@property NSUInteger outboundProxyPort;
@property NSString *STUNServerHost;
@property NSUInteger STUNServerPort;
@property NSString *userAgentString;
@property NSString *logFileName;
@property NSUInteger logLevel;
@property NSUInteger consoleLogLevel;
@property BOOL detectsVoiceActivity;
@property BOOL usesICE;
@property NSUInteger transportPort;
@property NSString *transportPublicHost;

// PJSUA config
//@property AKTelephoneCallData callData_[PJSUA_MAX_CALLS];
@property pj_pool_t *pjPool;
@property NSInteger ringbackSlot;
@property NSInteger ringbackCount;
@property pjmedia_port *ringbackPort;
@property pj_status_t  userAgentFailureStatus;

+ (TelephonyEndpoint *)sharedTelephone;

// Designated initializer
- (id)initWithDelegate:(id)aDelegate;

// Start SIP user agent.
- (void)startUserAgent;

// Stop SIP user agent.
- (void)stopUserAgent;

- (void)killUserAgent;

// Dealing with accounts
- (BOOL)addAccount:(TelephonyEndpointAccount *)anAccount withPassword:(NSString *)aPassword andSavantPhoneService:(BOOL)phoneService;
- (BOOL)removeAccount:(TelephonyEndpointAccount *)account;
- (TelephonyEndpointAccount *)accountByIdentifier:(NSInteger)anIdentifier;

// Dealing with calls
- (TelephonyEndpointCall *)telephoneCallByIdentifier:(NSInteger)anIdentifier;
- (void)hangUpAllCalls;

// Set new sound IO.
- (BOOL)setSoundInputDevice:(NSInteger)input soundOutputDevice:(NSInteger)output;
- (BOOL)stopSound;
- (BOOL)userAgentStarted;
// Update list of audio devices.
// After calling this method, setSoundInputDevice:soundOutputDevice: must be called
// to set appropriate IO.
- (void)updateAudioDevices;

- (NSString *)stringForSIPResponseCode:(NSInteger)responseCode;

@end


// Callback from PJSUA
void AKTelephoneDetectedNAT(const pj_stun_nat_detect_result *result);


@protocol AKTelephoneDelegate <NSObject>

@optional
- (BOOL)telephoneShouldAddAccount:(TelephonyEndpointAccount *)anAccount;

@end


// Notifications.
extern NSString * const AKTelephoneUserAgentDidFinishStartingNotification;
extern NSString * const AKTelephoneUserAgentDidFinishStoppingNotification;
extern NSString * const AKTelephoneDidDetectNATNotification;
