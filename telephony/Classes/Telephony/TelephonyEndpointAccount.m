//
//  AKTelephoneAccount.m
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
#import "TelephonySubscription.h"

//#import "rpmTelephonyUtils.h"

#import "NSString+PJSIP.h"
#import "AKSIPURI.h"
#import "TelephonyEndpoint.h"
#import "TelephonyEndpointCall.h"
#import <pjsua-lib/pjsua.h>
#import <pjsua-lib/pjsua_internal.h>
#import <pjsip-simple/evsub_msg.h>

NSString * const AKTelephoneAccountRegistrationDidChangeNotification
  = @"AKTelephoneAccountRegistrationDidChange";
NSString * const AKTelephoneAccountWillRemoveNotification
  = @"AKTelephoneAccountWillRemove";
/*YZhou*/
NSString * const AKTelephoneAccountSLANotification
= @"AKTelephoneAccountSLA";
NSString * const AKTelephoneAccountBLFNotification
= @"AKTelephoneAccountBLF";

NSString * const kAKDefaultSIPProxyHost = @"";
const NSInteger kAKDefaultSIPProxyPort = 5060;
const NSInteger kAKDefaultAccountReregistrationTime = 600;
extern pjsip_transport *the_transport;

@implementation TelephonyEndpointAccount

//- (NSObject <AKTelephoneAccountDelegate> *)delegate {
//  return self.delegate;
//}

//- (void)setDelegate:(NSObject <AKTelephoneAccountDelegate> *)aDelegate {
//  if (self.delegate == aDelegate)
//    return;
//  
//  //NSLog(@"setDelegate  : ct=%@ mt=%@", [NSThread currentThread], [NSThread mainThread]);
//  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
//  
//  if (self.delegate != nil)
//    [notificationCenter removeObserver:self.delegate name:nil object:self];
//  
//  if (aDelegate != nil) {
//    if ([aDelegate respondsToSelector:@selector(telephoneAccountRegistrationDidChange:)])
//      [notificationCenter addObserver:aDelegate
//                             selector:@selector(telephoneAccountRegistrationDidChange:)
//                                 name:AKTelephoneAccountRegistrationDidChangeNotification
//                               object:self];
//    
//    if ([aDelegate respondsToSelector:@selector(telephoneAccountWillRemove:)])
//      [notificationCenter addObserver:aDelegate
//                             selector:@selector(telephoneAccountWillRemove:)
//                                 name:AKTelephoneAccountWillRemoveNotification
//                               object:self];
//  /*YZhou*/	 
//	  if ([aDelegate respondsToSelector:@selector(telephoneAccountSLANotifyReceived:)])
//		  [notificationCenter addObserver:aDelegate
//								 selector:@selector(telephoneAccountSLANotifyReceived:)
//									 name:AKTelephoneAccountSLANotification
//								   object:self];
//	  if ([aDelegate respondsToSelector:@selector(telephoneAccountBLFNotifyReceived:)])
//		  [notificationCenter addObserver:aDelegate
//								 selector:@selector(telephoneAccountBLFNotifyReceived:)
//									 name:AKTelephoneAccountBLFNotification
//								   object:self];
//  }
//  
//  self.delegate = aDelegate;
//}

//- (NSUInteger)proxyPort {
//  return self.proxyPort;
//}
//
//- (void)setProxyPort:(NSUInteger)port {
//  if (port > 0 && port < 65535)
//    self.proxyPort = port;
//  else
//    self.proxyPort = kAKDefaultSIPProxyPort;
//}
//
//- (NSUInteger)reregistrationTime {
//  return self.reregistrationTime;
//}
//
//- (void)setReregistrationTime:(NSUInteger)seconds {
//  if (seconds == 0)
//    self.reregistrationTime = kAKDefaultAccountReregistrationTime;
//  else if (seconds < 60)
//    self.reregistrationTime = 60;
//  else if (seconds > 3600)
//    self.reregistrationTime = 3600;
//  else
//    self.reregistrationTime = seconds;
//}

- (BOOL)isRegistered {
  return ([self registrationStatus] / 100 == 2) &&
         ([self registrationExpireTime] > 0);
}

- (void)setRegistered:(BOOL)value {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return;
  
  if (value) {
    pjsua_acc_set_registration([self identifier], PJ_TRUE);
    [self setOnline:YES];
  } else {
    [self setOnline:NO];
    pjsua_acc_set_registration([self identifier], PJ_FALSE);
  }
}

- (NSInteger)registrationStatus {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return 0;
  
  pjsua_acc_info accountInfo;
  pj_status_t status;
  
  status = pjsua_acc_get_info([self identifier], &accountInfo);
  if (status != PJ_SUCCESS)
    return 0;
  
  return accountInfo.status;
}

- (NSString *)registrationStatusText {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return nil;
  
  pjsua_acc_info accountInfo;
  pj_status_t status;
  
  status = pjsua_acc_get_info([self identifier], &accountInfo);
  if (status != PJ_SUCCESS)
    return nil;
  
  return [NSString stringWithPJString:accountInfo.status_text];
}

- (NSInteger)registrationExpireTime {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return -1;
  
  pjsua_acc_info accountInfo;
  pj_status_t status;
  
  status = pjsua_acc_get_info([self identifier], &accountInfo);
  if (status != PJ_SUCCESS)
    return -1;
  
  return accountInfo.expires;
}

- (BOOL)isOnline {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return NO;
  
  pjsua_acc_info accountInfo;
  pj_status_t status;
  
  status = pjsua_acc_get_info([self identifier], &accountInfo);
  if (status != PJ_SUCCESS)
    return NO;
  
  return (accountInfo.online_status == PJ_TRUE) ? YES : NO;
}

- (void)setOnline:(BOOL)value {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return;
  
  if (value)
    pjsua_acc_set_online_status([self identifier], PJ_TRUE);
  else
    pjsua_acc_set_online_status([self identifier], PJ_FALSE);
}

- (NSString *)onlineStatusText {
  if ([self identifier] == kAKTelephoneInvalidIdentifier)
    return nil;
  
  pjsua_acc_info accountInfo;
  pj_status_t status;
  
  status = pjsua_acc_get_info([self identifier], &accountInfo);
  if (status != PJ_SUCCESS)
    return nil;
  
  return [NSString stringWithPJString:accountInfo.online_status_text];
}

+ (id)telephoneAccountWithFullName:(NSString *)aFullName
                        SIPAddress:(NSString *)aSIPAddress
                         registrar:(NSString *)aRegistrar
                             realm:(NSString *)aRealm
                          username:(NSString *)aUsername 
                          password:(NSString *)aPassword registrarNeeded:(BOOL)flag
{
  return [[TelephonyEndpointAccount alloc] initWithFullName:aFullName
                                            SIPAddress:aSIPAddress
                                             registrar:aRegistrar
                                                 realm:aRealm
                                              username:aUsername password:aPassword registrarNeeded:flag];
}

- (id)initWithFullName:(NSString *)aFullName
            SIPAddress:(NSString *)aSIPAddress
             registrar:(NSString *)aRegistrar
                 realm:(NSString *)aRealm
              username:(NSString *)aUsername 
              password:(NSString *)aPassword registrarNeeded:(BOOL)flag
{
  self = [super init];
  if (self == nil)
    return nil;
  
  self.registrationURI=[AKSIPURI SIPURIWithString:
                            [NSString stringWithFormat:@"\"%@\" <sip:%@>",
                             aFullName, aSIPAddress]];
  
  self.fullName=aFullName;
  self.SIPAddress=aSIPAddress;
  self.registrar=aRegistrar;
  self.realm=aRealm;
  self.username=aUsername;
  self.proxyHost=kAKDefaultSIPProxyHost;
  self.proxyPort=kAKDefaultSIPProxyPort;
  self.reregistrationTime=kAKDefaultAccountReregistrationTime;
  self.identifier=kAKTelephoneInvalidIdentifier;
  self.password=aPassword;
  self.registrarNeeded=flag;
  self.calls = [[NSMutableArray alloc] init];
  self.subscriptions = [[NSMutableArray alloc] init];
  self.blf_subscriptions = [[NSMutableArray alloc] init];
  
  return self;
}

- (id)init {
  return [self initWithFullName:nil
                     SIPAddress:nil
                      registrar:nil
                          realm:nil
                       username:nil password:nil registrarNeeded:NO];
}


- (NSString *)description {
  return [self SIPAddress];
}

// Make outgoing call, create call object, set its info, add to the array
//- (TelephonyEndpointCall *)makeCallTo:(AKSIPURI *)destinationURI isIntercomCall:(BOOL)isIntercomCall
//{
//    pjsua_call_id callIdentifier;
//    NSString *uriUdp = [destinationURI description];
//    pj_str_t uri ;
//
//	pj_status_t status;
//    
//    //Now depending if it is the Phoneservice
//    // we replace the transport to be tcp instead
//    
////    if([self.delegate isRPMPhoneServiceEnabled])
//    {
//        uri = [ [uriUdp  stringByReplacingOccurrencesOfString:@"udp" withString:@"tcp"] pjString];
//    }
////    else 
////    {
////        uri = [uriUdp pjString];
////    }
//
//    //Now we insert the Savant Header to indicate Intercom call (1-way)
//    // for now we always do this. In the future will depend of the service
//    
//	pjsua_msg_data msg_data;
//    if(isIntercomCall)
//    {
//        pjsip_generic_string_hdr my_hdr;
//        pj_str_t hname = pj_str("X-Savant-CallType");
//        pj_str_t hvalue = pj_str("Intercom");
//    
//        pjsua_msg_data_init(&msg_data);
//        pjsip_generic_string_hdr_init2(&my_hdr, &hname, &hvalue);
//        pj_list_push_back(&msg_data.hdr_list, &my_hdr);
//        
//        status = pjsua_call_make_call([self identifier], &uri, 0, NULL, &msg_data, &callIdentifier);
//    }
//    else
//    {
//        status = pjsua_call_make_call([self identifier], &uri, 0, NULL, NULL, &callIdentifier);
//    }
//
//    
//    if (status != PJ_SUCCESS) 
//    {
//        NSLog(@"Error making call to %@ via account %@", destinationURI, self);
//        return nil;
//    }
////#ifndef SINGEL_CALL
////    TelephonyAccountController *accountController =  [[rpmTelephonyUtils rpmTelephonyUtilsGetTelephonyAppController] getCurrentTelephonyAccountController];
////    [accountController setActiveCallIdentifier:callIdentifier];
////#endif
//  
//  // AKTelephoneCall object is created here when the call is outgoing
//  TelephonyEndpointCall *theCall
//    = [[TelephonyEndpointCall alloc] initWithTelephoneAccount:self
//                                             identifier:callIdentifier];
//
//  [theCall setIntercomCall:isIntercomCall];
//  // Keep this call in the calls array for this account
//  [[self calls] addObject:theCall];
//  
//  return theCall;
//}


//- (void)setLineEnabled:(NSInteger)line withValue:(BOOL)value
//{
//    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
//    {
//        lineEnabled_[line] = value;
//    }
//}

//- (BOOL)lineEnabled:(NSInteger)line
//{
//    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
//    {
//        return lineEnabled_[line];
//    }
//    return (FALSE);
//}

//- (void)setLine:(NSInteger)line withID:(NSString *)lineId
//{
//    NSString *lineKey = [NSString stringWithFormat:@"Line %d", line];
//    NSDictionary *d = [NSDictionary dictionaryWithObject:lineId forKey:lineKey];
//    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
//    {
//        [lines_ addObject:d];
//    }
//}


//- (NSString *)getLineID:(NSInteger)line
//{
//    NSString *lineKey = [NSString stringWithFormat:@"Line %d", line];
//    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
//    {
//        for(NSDictionary *d in lines_)
//        {
//            NSArray *key = [d allKeys];
//            if([[key objectAtIndex:0] isEqualToString:lineKey])
//            {
//                return [d objectForKey:lineKey];
//            }
//        }
//    }
//    return nil;
//}


//new SLA subscription logic
- (void)setLineEnabled:(NSInteger)line withValue:(BOOL)value
{
    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
    {
        for (id subscription in self.subscriptions)
        {
//            if ([subscription isKindOfClass:[TelephonySLASubscription class]])
            {
                if([subscription line] == line)
                {
                    [subscription setEnabled:value];
                }
            }
        }
    }
}


- (BOOL)lineEnabled:(NSInteger)line
{
    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
    {
        for (id subscription in self.subscriptions)
        {
//            if ([subscription isKindOfClass:[TelephonySLASubscription class]])
            {
                if([subscription line] == line)
                {
                    return [subscription isSubscriptionEnabled];
                }
            }
        }
    }
    
    return (FALSE);
}

- (void)setLine:(NSInteger)line withID:(NSString *)lineId
{
//    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
//    {
//        TelephonySLASubscription *sla =[[[TelephonySLASubscription alloc] init] autorelease];
//        [sla setName:lineId];
//        [sla setLine:line];
//        
//        [self.subscriptions addObject:sla];
//    }
}

- (NSString *)getLineID:(NSInteger)line
{
    for (id subscription in self.subscriptions)
    {
//        if ([subscription isKindOfClass:[TelephonySLASubscription class]])
        {
            if([subscription line] == line)
            {
                return [subscription name];
            }
        }
    }
    
    return nil;
}

#pragma mark -
#pragma mark BLF subscriptions

//-(BOOL)findBLFSubscription:(NSString*)remoteExtension
//{
//    for (id subscription in blf_self.subscriptions)
//    {
//        if ([subscription isKindOfClass:[TelephonyBLFSubscription class]])
//        {
//            if([[subscription name] isEqualToString: remoteExtension] && [subscription isSubscriptionEnabled])
//            {
//                return TRUE;
//            }
//        }
//    }
//    
//    return FALSE;
//}
//-(NSString *)findBLFSubscriptionForDialogId:(NSString*)dialogId
//{
//    for (id subscription in blf_self.subscriptions)
//    {
//        if ([subscription isKindOfClass:[TelephonyBLFSubscription class]])
//        {
//            if([[subscription name] isEqualToString: dialogId] && [subscription isSubscriptionEnabled])
//            {
//                return [subscription name];
//            }
//        }
//    }
//    
//    return nil;
//}
//-(NSInteger)getBLFSubscriptionIndexForDialogId:(NSString*)dialogId
//{
//    NSInteger index;
//    for (index=0; index < [blf_self.subscriptions count]; index++)
//    {
//        id subscription = [blf_self.subscriptions objectAtIndex:index];
//        if ([subscription isKindOfClass:[TelephonyBLFSubscription class]])
//        {
//            if([[subscription name] isEqualToString: dialogId] && [subscription isSubscriptionEnabled])
//            {
//                return index;
//            }
//        }
//    }
//    
//    return kAKTelephoneInvalidBLFSubscriptionIndex;
//}
//-(NSInteger)_getBLFSubscriptionEmptyIndexForDialogId:(NSString*)dialogId
//{
//    NSInteger index;
//    for (index=0; index < [blf_self.subscriptions count]; index++)
//    {
//        id subscription = [blf_self.subscriptions objectAtIndex:index];
//        if ([subscription isKindOfClass:[TelephonyBLFSubscription class]])
//        {
//            if(![subscription isSubscriptionEnabled])
//            {
//                return index;
//            }
//        }
//    }
//    
//    return kAKTelephoneInvalidBLFSubscriptionIndex;
//}
//-(NSInteger)createBLFForRemoteExtension:(NSString*)remoteExtension
//{
//    NSInteger index = [self _getBLFSubscriptionEmptyIndexForDialogId:remoteExtension];
//    if(index != kAKTelephoneInvalidBLFSubscriptionIndex)
//    {
//        TelephonyBLFSubscription *slot = [blf_self.subscriptions objectAtIndex:index];
//        [slot setName:remoteExtension];
//        [slot setRemoteDeviceExtension:[remoteExtension intValue]];
//        [slot setEnabled:YES];
//        return index;
//    }
//    else
//    {
//        TelephonyBLFSubscription *blf =[[[TelephonyBLFSubscription alloc] init] autorelease];
//        [blf setName:remoteExtension];
//        [blf setRemoteDeviceExtension:[remoteExtension intValue]];
//        [blf setEnabled:YES]; // for now set it here
//        [blf_self.subscriptions addObject:blf ];
//        return [blf_self.subscriptions indexOfObject:blf];
//    }
//    
//}
//-(void)deleteBLFSubscriptionByIndex:(NSInteger)blfIndex
//{
//    TelephonyBLFSubscription *blf = [blf_self.subscriptions objectAtIndex:blfIndex];
//    [blf setEnabled:FALSE];
//}
//-(void)disableBLFSubscriptionByIndex:(NSInteger)blfIndex
//{
//    TelephonyBLFSubscription *blf = [blf_self.subscriptions objectAtIndex:blfIndex];
//    [blf setEnabled:FALSE];
//}
//
@end


#pragma mark -
#pragma mark Callbacks

void AKTelephoneAccountRegistrationStateChanged(pjsua_acc_id accountIdentifier, pjsua_reg_info *reg_info)
{
    struct pjsip_regc_cbparam *rp = reg_info->cbparam;

    if (the_transport)
    {
        pjsip_transport_dec_ref(the_transport);
        the_transport =NULL;
    }
    //save the transport instance so that we can close ot later when
    // new IP address is detected
    if (rp->rdata)
    {
        the_transport = rp->rdata->tp_info.transport;
        pjsip_transport_add_ref(the_transport);
    }

    TelephonyEndpointAccount *anAccount = [[TelephonyEndpoint sharedTelephone]
    accountByIdentifier:accountIdentifier];
    //NSLog(@"AKTelephoneAccountRegistrationStateChanged  for account %@", anAccount);
    //NSLog(@"AKTelephoneAccountRegistrationStateChanged  : ct=%@ mt=%@", [NSThread currentThread], [NSThread mainThread]);
    NSNotification *notification
    = [NSNotification
    notificationWithName:AKTelephoneAccountRegistrationDidChangeNotification
    object:anAccount];

    [[NSNotificationCenter defaultCenter]
    performSelectorOnMainThread:@selector(postNotification:)
    withObject:notification
    waitUntilDone:NO];
}

void AKTelephoneMWINotify(pjsua_acc_id acc_id, pjsua_mwi_info *mwi_info)
{
	//NSLog(@"MWI notification");
}

//bool isABLFNotify(pjsua_sla_info *sla_info)
//{
//    if (sla_info->rdata == NULL)
//    {
//        if (sla_info->type == PJSUA_SLA_SUBSCRIPTION_TYPE_BLF)
//        {
//            return TRUE;
//        }
//        else
//        {
//            return FALSE;
//        }
//    }
//    NSString      *theData = [[[NSString alloc] initWithBytes:sla_info->rdata->msg_info.msg->body->data
//                                                length:sla_info->rdata->msg_info.msg->body->len encoding:NSUTF8StringEncoding] autorelease];
//    return [rpmTelephonyUtils telephonyIsBLFDialogID:theData];
//}

//void AKTelephoneSLANotify(pjsua_acc_id acc_id, pjsua_sla_info *sla_info)
//{
//	pjsip_sub_state_hdr *sub_state;
//	pj_str_t hname = pj_str("Subscription-State");
//	NSMutableDictionary *d = nil;
//	
//	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//	bool isBLF = isABLFNotify(sla_info);
//    
//	if (sla_info->rdata == NULL)
//	{
//		if(pjsip_evsub_get_state(sla_info->evsub) == PJSIP_EVSUB_STATE_TERMINATED)
//		{
//			d = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"terminated", @"state", [NSNumber numberWithInt:sla_info->line], @"line", nil];
//            if (0) //(sla_info->type == PJSUA_SLA_SUBSCRIPTION_TYPE_BLF)
//            {
//                [d setObject:@"BLF" forKey:@"SubscriptionType"];
//            }
//            else
//            {
//                [d setObject:@"SLA" forKey:@"SubscriptionType"];                
//            }
//		}
//	}
//	else 
//	{
//        NSData      *notifyData = [[[NSData alloc]initWithBytes:sla_info->rdata->msg_info.msg->body->data
//                                                         length:sla_info->rdata->msg_info.msg->body->len] autorelease];
//        
//        sub_state = (pjsip_sub_state_hdr*)pjsip_msg_find_hdr_by_name(sla_info->rdata->msg_info.msg, &hname, NULL);
//        
//        if(sub_state)
//        {
//            NSString *state = [NSString stringWithPJString:sub_state->sub_state];
//            d = [NSMutableDictionary dictionaryWithObjectsAndKeys:notifyData,@"data",state,@"state",nil];            
//            if (sub_state->reason_param.ptr)
//            {
//                [d setObject:[NSString stringWithPJString:sub_state->reason_param] forKey:@"reason"];
//            }
//        }
//        else
//        {
//            d = [NSMutableDictionary dictionaryWithObject:notifyData forKey:@"data"];
//        }
//
//        if(isBLF)
//        {
//            // BLF
//            [d setObject:@"BLF" forKey:@"SubscriptionType"];
//        }
//        else
//        {
//            // SLA
//            
//            [d setObject:@"SLA" forKey:@"SubscriptionType"];
//        }
//	}
//	TelephonyEndpointAccount *anAccount = [[TelephonyEndpoint sharedTelephone]
//										   accountByIdentifier:acc_id];
//	if(d)
//	{
//        NSString *note;
//        if(isBLF)
//        {
//            note = AKTelephoneAccountBLFNotification;
//        }
//        else
//        {
//            note =AKTelephoneAccountSLANotification;
//        }
//        
//		NSNotification *notification= [NSNotification notificationWithName:note object:anAccount userInfo:d];
//		[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
//	}
//}
