//
//  AccountController.h
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

#import "TelephonyEndpointAccount.h"
//#import "TelephonyCallController.h"
//#import "Reachability.h"

#import "Telephony.h"
/*YZhou*/
//#import "UIKit/UIKit.h"

@class TelephonyEndpoinAccount, AKNetworkReachability;

	
@interface TelephonyAccountController : NSObject 

@property id appController;
@property TelephonyEndpointAccount *account;
@property NSMutableArray *callControllers;

@property BOOL attemptingToRegisterAccount;
@property BOOL attemptingToUnregisterAccount;
@property BOOL accountUnavailable;
@property NSTimer *reRegistrationTimer;
@property BOOL shouldMakeCall;
@property NSString *catchedURLString;
//  AKNetworkReachability *registrarReachability_;

@property BOOL hasActiveCall; //AOB
@property BOOL substitutesPlusCharacter;
@property NSString *plusCharacterSubstitution;

@property NSUInteger callDestinationURIIndex;
@property NSString *callDestinationField;
@property NSString *callDestinationDisplayField;

@property NSMutableArray *missedCalls; //AOB
@property BOOL doNotDisturbEnabled;
@property BOOL autoAnswerEnabled;
@property BOOL registrarNeeded;
@property BOOL intercomCall;
@property BOOL endpointDontShow;
@property BOOL endpointShowAll;
@property BOOL systemSelectorWindowActive;
@property BOOL selectLineThenDial;
@property BOOL phoneService;
@property NSMutableString *dialedNumberAfterDialTone;

// Designated initializer
- (id)initWithTelephoneAccount:(TelephonyEndpointAccount *)anAccount;

- (id)initWithFullName:(NSString *)aFullName
            SIPAddress:(NSString *)aSIPAddress
             registrar:(NSString *)aRegistrar
                 realm:(NSString *)aRealm
              username:(NSString *)aUsername
              password:(NSString *)aPassword registrarNeeded:(BOOL)flag;


@end
