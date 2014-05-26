//
//  AccountController.m
//  Telephone
//
//  Copyright (c) 2008-2009 Alexei Kuznetsov. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY ALEXEI KUZNETSOV "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
//  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//


#import "TelephonyAccountController.h"
#import "TelephonyEndpoint.h"
#import "TelephonyEndpointAccount.h"
#import "TelephonyAppController.h"
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>

@implementation TelephonyAccountController

- (id)initWithTelephoneAccount:(TelephonyEndpointAccount *)anAccount
{
    self = [super init];
    if (self == nil)
        return nil;
  
    self.account=anAccount;
    self.callControllers = [[NSMutableArray alloc] init];
    self.missedCalls    = [[NSMutableArray alloc] init];
	self.dialedNumberAfterDialTone = [[NSMutableString alloc] init];
	self.selectLineThenDial=NO;
    self.substitutesPlusCharacter=NO;
  
    self.attemptingToRegisterAccount=NO;
    self.attemptingToUnregisterAccount=NO;
    self.accountUnavailable=NO;
    self.shouldMakeCall=NO;
    
    //AOB
    // Telephony Bug 21275
//    TelephonyAppController *telephonyController_ =  [rpmTelephonyUtils rpmTelephonyUtilsGetTelephonyAppController];
//    self.phoneService= [telephonyController_ isRPMPhoneServiceEnabled];
//
//    if([self isRPMPhoneServiceEnabled])
    {
        // For Phone  we will default to NO but after that we will use the current value [[NSUserDefaults  standardUserDefaults]      boolForKey:kTelephonyCommandRequestAutoAnswer]]
        NSNumber *phoneAutoAnswer = [[NSUserDefaults  standardUserDefaults]  objectForKey:kTelephonyCommandRequestPhoneAutoAnswer];
        if (phoneAutoAnswer == nil)
        {            
            [[NSUserDefaults  standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:kTelephonyCommandRequestPhoneAutoAnswer];
            [self setAutoAnswerEnabled:NO ];
        }
        else
        {
            [self setAutoAnswerEnabled:[[[NSUserDefaults  standardUserDefaults]    objectForKey:kTelephonyCommandRequestPhoneAutoAnswer] boolValue]  ];
        }
    }
//    else
//    {
//        // For Intercom we will default to YES but after that we will use the current value [[NSUserDefaults  standardUserDefaults]      boolForKey:kTelephonyCommandRequestAutoAnswer]]
//        NSNumber *autoAnswer = [[NSUserDefaults  standardUserDefaults]  objectForKey:kTelephonyCommandRequestIntercomAutoAnswer];
//        if (autoAnswer == nil)
//        {
//            [[NSUserDefaults  standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:kTelephonyCommandRequestIntercomAutoAnswer];
//            [self setAutoAnswerEnabled:YES ];
//        }
//        else
//        {
//            [self setAutoAnswerEnabled:[[[NSUserDefaults  standardUserDefaults]    objectForKey:kTelephonyCommandRequestIntercomAutoAnswer] boolValue]  ];
//        }
//    }

    
    self.doNotDisturbEnabled=[[NSUserDefaults  standardUserDefaults]    boolForKey:kTelephonyCommandRequestDoNotDisturb];
//    self.account.delegate=self;
  
  
    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(telephoneUserAgentDidFinishStarting:)
          name:AKTelephoneUserAgentDidFinishStartingNotification
        object:nil];
    
    //AOB   
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(sipMakeIntercomCallNotificationHandler:) 
     name:@"IntercomStartCall" 
     object:nil];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(toggleAutoAnswerButton:) 
     name:@"AutoAnswerChange" 
     object:nil];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(toggleDoNotDisturbButton:) 
     name:@"DoNotDisturbChange" 
     object:nil];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(iPadInSystemSelectorWindowNotification:)
     name:@"iPadInSystemSelectorWindowNotification"
     object:nil];

    //AOB: Phone Service
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(sipMakeCallNotificationHandler:) 
     name:@"PhoneStartCall" 
     object:nil];
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(sipPhonePageCallNotificationHandler:) 
     name:@"PhonePageAllCall" 
     object:nil];
	/*YZhou*/
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(sharedLineHandler:) 
     name:@"SharedLinePressed" 
     object:nil];    
	[[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(processCallDidDisconnected:) 
     name:@"CallControllerDisconnectNotification" 
     object:nil]; 
	[[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(processCallDidConfirm) 
     name:@"CallControllerConfirmNotification" 
     object:nil]; 	
    [[NSNotificationCenter defaultCenter] 
	 addObserver:self
	 selector:@selector(phoneRedialPressed)
	 name:@"PhoneRedialPressed"
	 object:nil]; 
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(sipMWIHandler:) 
     name:@"SIPMwiIndication" 
     object:nil];
	[[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(processCallWaitingIndication:) 
     name:@"incomingCallWaitingCall"
     object:nil];
	[[NSNotificationCenter  defaultCenter] 
	 addObserver:self 
	 selector:@selector(digitNotificationHandler:) 
	 name:@"PhoneSendDTMFDigit" 
	 object:nil];	
	
	[[NSNotificationCenter  defaultCenter]
	 addObserver:self
	 selector:@selector(telephonyBLFStartHandler:)
	 name:@"com.savantsystems.telephony.blf.start"
	 object:nil];
	[[NSNotificationCenter  defaultCenter]
	 addObserver:self
	 selector:@selector(telephonyBLFStopHandler:)
	 name:@"com.savantsystems.telephony.blf.stop"
	 object:nil];

#ifndef SINGLE_CALL
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(telephonyAnswerCallNotificationHandler:) name:@"PhoneAnswerCall" object:nil];
#endif
    
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(telephonyMultiCallSwapNotificationHandler:) name:@"PhoneMultiCallSwapPressed" object:nil];
    
    //NSLog(@"initWithTelephoneAccount  : ct=%@ mt=%@", [NSThread currentThread], [NSThread mainThread]);
//    [[rpmStateManager sharedrpmStateManager]registerState:[NSString stringWithFormat:@"telephony.%@.SLACall", [anAccount fullName]]
//                                                forTarget:self];
//    [ [rpmStateManager sharedrpmStateManager] updateLocalState:[NSString stringWithFormat:@"%@.%@",@"local",@"GateStationCall"] withValue: @"0"];
//    
//    player_id = -1;
//    
//    [self registerForNetworkReachabilityNotifications];

    return self;
}

- (id)initWithFullName:(NSString *)aFullName
            SIPAddress:(NSString *)aSIPAddress
             registrar:(NSString *)aRegistrar
                 realm:(NSString *)aRealm
              username:(NSString *)aUsername
              password:(NSString *)aPassword registrarNeeded:(BOOL)flag
{
  TelephonyEndpointAccount *anAccount
    = [TelephonyEndpointAccount telephoneAccountWithFullName:aFullName
                                            SIPAddress:aSIPAddress
                                             registrar:aRegistrar
                                                 realm:aRealm
                                              username:aUsername 
                                              password:aPassword registrarNeeded:flag];
  self.registrarNeeded=flag;
  self.phoneService=FALSE;
  //NSLog(@"test =%d %d %d", flag, [self isRegistrarNeeded], [anAccount isRegistrarNeeded]);
	return [self initWithTelephoneAccount:anAccount];
}

@end