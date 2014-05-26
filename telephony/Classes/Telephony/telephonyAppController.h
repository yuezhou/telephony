//
//  telephonyAppController.m
//  rpmPadController
//
//  Created by Alejandro Orellana on 6/7/10.
//  Copyright 2010 Savant Systems, LLC. All rights reserved.
//

#import "TelephonyEndpoint.h"
#import "TelephonyAccountController.h"

extern NSString * const kAccounts;
extern NSString * const kSTUNServerHost;
extern NSString * const kSTUNServerPort;
extern NSString * const kSTUNDomain;
extern NSString * const kLogFileName;
extern NSString * const kLogLevel;
extern NSString * const kConsoleLogLevel;
extern NSString * const kVoiceActivityDetection;
extern NSString * const kTransportPort;
extern NSString * const kTransportPublicHost;
extern NSString * const kSoundInput;
extern NSString * const kSoundOutput;
extern NSString * const kRingtoneOutput;
extern NSString * const kRingingSound;
extern NSString * const kFormatTelephoneNumbers;
extern NSString * const kTelephoneNumberFormatterSplitsLastFourDigits;
extern NSString * const kOutboundProxyHost;
extern NSString * const kOutboundProxyPort;
extern NSString * const kUseICE;
extern NSString * const kUseDNSSRV;
extern NSString * const kSignificantPhoneNumberLength;
extern NSString * const kPauseITunes;
extern NSString * const kAutoCloseCallWindow;
extern NSString * const kVoicemailNumber;
// Account keys
extern NSString * const kDescription;
extern NSString * const kFullName;
extern NSString * const kAccountPassword;
extern NSString * const kSIPAddress;
extern NSString * const kRegistrar;
extern NSString * const kDomain;
extern NSString * const kRealm;
extern NSString * const kUsername;
extern NSString * const kAccountIndex;
extern NSString * const kAccountEnabled;
extern NSString * const kReregistrationTime;
extern NSString * const kSubstitutePlusCharacter;
extern NSString * const kPlusCharacterSubstitutionString;
extern NSString * const kUseProxy;
extern NSString * const kProxyHost;
extern NSString * const kProxyPort;

extern NSString * const kSourceIndex;
extern NSString * const kDestinationIndex;
extern NSString * const kSavantType;
extern NSString * const kSavantVideo;
@interface TelephonyAppController : NSObject

@property id parent;
@property NSDictionary       *telephonyEndPoints;
@property TelephonyEndpoint  *telephone;
@property NSMutableArray  *accountControllers;
@property NSMutableDictionary *remoteEndPoints;
@property BOOL phoneService;

- (id)initWithParentId:(id)parentId andTelephonyEndPoints:(NSDictionary*)endpoints;

-(void)SavantCallSeverFound:(NSNotification *)notification;
-(void)remoteEndpointsAlloc;
- (void)setupDefaultsWithContentsOfConfigurationFile:(NSDictionary *)settingsDict andRegistrarIpAddress:(NSString *)bonjourRegistrar;

@end