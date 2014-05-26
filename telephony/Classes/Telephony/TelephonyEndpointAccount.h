//
//  AKTelephoneAccount.h
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

//#import <Foundation/Foundation.h>
#import <pjsua-lib/pjsua.h>


extern NSString * const kAKDefaultSIPProxyHost;
extern const NSInteger kAKDefaultSIPProxyPort;
extern const NSInteger kAKDefaultAccountReregistrationTime;
extern const NSInteger kAKTelephoneInvalidBLFSubscriptionIndex;


@class TelephonyEndpointCall, AKSIPURI;


@interface TelephonyEndpointAccount : NSObject

@property AKSIPURI *registrationURI;

@property NSString *fullName;
@property NSString *SIPAddress;
@property NSString *registrar;
@property NSString *realm;
@property NSString *username;
@property NSString *proxyHost;
@property NSUInteger proxyPort;
@property NSUInteger reregistrationTime;
@property NSString  *password;

@property NSInteger identifier;

@property NSMutableArray *calls;
@property BOOL registrarNeeded;
@property BOOL rejectedInBackground;
//AOB new implementation for subscription (sla and blf)
@property NSMutableArray *subscriptions; // for SLA
@property NSMutableArray *blf_subscriptions; // for BLF

+ (id)telephoneAccountWithFullName:(NSString *)aFullName
                        SIPAddress:(NSString *)aSIPAddress
                         registrar:(NSString *)aRegistrar
                             realm:(NSString *)aRealm
                          username:(NSString *)aUsername
                          password:(NSString *)aPassword registrarNeeded:(BOOL)flag;

- (id)initWithFullName:(NSString *)aFullName
            SIPAddress:(NSString *)aSIPAddress
             registrar:(NSString *)aRegistrar
                 realm:(NSString *)aRealm
              username:(NSString *)aUsername
              password:(NSString *)aPassword registrarNeeded:(BOOL)flag;

//- (TelephonyEndpointCall *)makeCallTo:(AKSIPURI *)destinationURI isIntercomCall:(BOOL)isIntercomCall;
//- (void)setLineEnabled:(NSInteger)line withValue:(BOOL)value;
//- (BOOL)lineEnabled:(NSInteger)line;
//- (void)setLine:(NSInteger)line withID:(NSString *)lineId;
//- (NSString *)getLineID:(NSInteger)line;
//
//-(NSInteger)createBLFForRemoteExtension:(NSString*)remoteExtension;
//-(BOOL)findBLFSubscription:(NSString*)remoteExtension;
//-(NSString *)findBLFSubscriptionForDialogId:(NSString*)dialogId;
//-(NSInteger)getBLFSubscriptionIndexForDialogId:(NSString*)dialogId;
//-(void)deleteBLFSubscriptionByIndex:(NSInteger)blfIndex;
//-(void)disableBLFSubscriptionByIndex:(NSInteger)blfIndex;
@end


// Callback from PJSUA
void AKTelephoneAccountRegistrationStateChanged(pjsua_acc_id accountIdentifier, pjsua_reg_info *reg_info);
void AKTelephoneMWINotify(pjsua_acc_id acc_id, pjsua_mwi_info *mwi_info);
void AKTelephoneSLANotify(pjsua_acc_id acc_id, pjsua_sla_info *sla_info);

@protocol AKTelephoneAccountDelegate

@optional
- (void)telephoneAccountDidReceiveCall:(TelephonyEndpointCall *)aCall;
-(BOOL)isRPMPhoneServiceEnabled;
@end


// Notifications.
extern NSString * const AKTelephoneAccountRegistrationDidChangeNotification;
extern NSString * const AKTelephoneAccountWillRemoveNotification;
extern NSString * const AKTelephoneAccountSLANotification;
extern NSString * const AKTelephoneAccountBLFNotification;
