//
//  telephonyAppController.m
//  rpmPadController
//
//  Created by Alejandro Orellana on 6/7/10.
//  Copyright 2010 Savant Systems, LLC. All rights reserved.
//

#import "telephonyAppController.h"

@implementation TelephonyAppController

NSString * const kAccounts = @"Accounts";
NSString * const kSTUNServerHost = @"STUNServerHost";
NSString * const kSTUNServerPort = @"STUNServerPort";
NSString * const kSTUNDomain = @"STUNDomain";
NSString * const kLogFileName = @"LogFileName";
NSString * const kLogLevel = @"LogLevel";
NSString * const kConsoleLogLevel = @"ConsoleLogLevel";
NSString * const kVoiceActivityDetection = @"VoiceActivityDetection";
NSString * const kTransportPort = @"TransportPort";
NSString * const kTransportPublicHost = @"TransportPublicHost";
NSString * const kSoundInput = @"SoundInput";
NSString * const kSoundOutput = @"SoundOutput";
NSString * const kRingtoneOutput = @"RingtoneOutput";
NSString * const kRingingSound = @"RingingSound";
NSString * const kFormatTelephoneNumbers = @"FormatTelephoneNumbers";
NSString * const kTelephoneNumberFormatterSplitsLastFourDigits
= @"TelephoneNumberFormatterSplitsLastFourDigits";
NSString * const kOutboundProxyHost = @"OutboundProxyHost";
NSString * const kOutboundProxyPort = @"OutboundProxyPort";
NSString * const kUseICE = @"UseICE";
NSString * const kUseDNSSRV = @"UseDNSSRV";
NSString * const kSignificantPhoneNumberLength = @"SignificantPhoneNumberLength";
NSString * const kPauseITunes = @"PauseITunes";
NSString * const kAutoCloseCallWindow = @"AutoCloseCallWindow";
NSString * const kVoicemailNumber = @"VoicemailNumber";
NSString * const kDescription = @"Description";
NSString * const kFullName = @"FullName";
NSString * const kSIPAddress = @"SIPAddress";
NSString * const kRegistrar = @"Registrar";
NSString * const kDomain = @"Domain";
NSString * const kRealm = @"Realm";
NSString * const kUsername = @"Username";
NSString * const kAccountPassword = @"Password";
NSString * const kAccountIndex = @"AccountIndex";
NSString * const kAccountEnabled = @"AccountEnabled";
NSString * const kReregistrationTime = @"ReregistrationTime";
NSString * const kSubstitutePlusCharacter = @"SubstitutePlusCharacter";
NSString * const kPlusCharacterSubstitutionString
= @"PlusCharacterSubstitutionString";
NSString * const kUseProxy = @"UseProxy";
NSString * const kProxyHost = @"ProxyHost";
NSString * const kProxyPort = @"ProxyPort";

NSString * const kSourceIndex = @"SourceIndex";
NSString * const kDestinationIndex = @"DestinationIndex";
NSString * const kSavantType = @"Type";
NSString * const kSavantVideo = @"Video";


- (id)initWithParentId:(id)parentId andTelephonyEndPoints:(NSDictionary*)endpoints
{
//    self = [super init];
    if (self == nil)
        return nil;
    
//    parent = parentId;
    self.telephonyEndPoints = endpoints;
    
//    self.stateCenterRunnig = FALSE;
    self.telephone = [TelephonyEndpoint sharedTelephone];
//    [self setMissedCallStatus:@"Off"];
//    [self setLinesStatus:@"Off"];
//    [[self telephone] setDelegate:self];
    
    // notification for when the savant call server has been found
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SavantCallSeverFound:) name:@"Savant_AsteriskFound" object:nil];
    
    // notification for when the savant call server has been found UIApplicationDidBecomeActiveNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SavantStateCenterFound:) name:@"StateCenterFound" object:nil];
    
    // notification for when app has come back from sleep mode
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processBLFStatusNotification:) name:@"com.savantsystems.telephony.blf.status" object:nil];

    self.accountControllers = [[NSMutableArray alloc] init]; 
    
    [self remoteEndpointsAlloc];//non bonjour local remote endpoint list
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processUIApplicationDidBecomeActiveNotification) name:UIApplicationDidBecomeActiveNotification object:nil];
    
//    NSNumber *phoneEnabled = [[rpmStateManager sharedrpmStateManager] getLocalState: @"local.PhoneServiceEnabled"];
//    
//    if ([phoneEnabled  boolValue])
    {
        //Now we register for DIS events
//        _disStates = [rpmDISStates sharedDISStates];
        
        //[_disStates startConnection]; 
        
//        [_disStates registerState:@"dis.telephony.registrationInfoChange"];
//        [_disStates registerState:@"dis.telephony.endpointConfigurationChange"];
//        [_disStates registerState:@"dis.telephony.amiConnectionStatusChange"];
//        [_disStates registerState:@"dis.telephony.configurationDatabaseReload"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStateValues:)
                                                     name:@"dis.telephony.registrationInfoChange"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStateValues:)
                                                     name:@"dis.telephony.endpointConfigurationChange"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStateValues:)
                                                     name:@"dis.telephony.amiConnectionStatusChange"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStateValues:)
                                                     name:@"dis.telephony.configurationDatabaseReload"
                                                   object:nil];
        
//        [[rpmStateManager sharedrpmStateManager] registerState:@"local.ConnectionStatus" forTarget:self];

//        [self initABContactRecords];
//        memset(toneBuffer, 0, sizeof(AudioBufferList)*12);
//		[self setKeypadAudioUnit:NO];
//        [self getAudioFileFormatAndContent];
//        [[AVAudioSession sharedInstance]setDelegate:self];
//        if([[UIDevice currentDevice].systemVersion floatValue] >= 6.0)
//        {
//            [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
//        }
//        else
//        {
//            [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:nil];
//        }
//        defaultRingNames_ = [[NSArray  arrayWithObjects:
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 1",@"UIName",@"ringtone1",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 2",@"UIName",@"ringtone2",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 3",@"UIName",@"ringtone3",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 4",@"UIName",@"ringtone4",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 5",@"UIName",@"ringtone5",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Tone 6",@"UIName",@"ringtone6",@"Filename",nil],
//                              [NSDictionary dictionaryWithObjectsAndKeys:@"Silent",@"UIName",@"silent",@"Filename",nil],
//                              nil] retain];

        //default Ringtone Info
//        NSString *localSelectedRingtone = [[NSUserDefaults  standardUserDefaults]  stringForKey:kTelephonyNSUserDefaultsLocalSelectedRingtoneName];
//        if (localSelectedRingtone ==  nil || [localSelectedRingtone isEqualToString:@"None"])
//        {
//            [self setPhoneCurrentRingtoneName:kTelephonyDefaultRingtoneName];
//            [self setPhoneCurrentRingtoneIndex:[NSIndexPath indexPathForRow:0 inSection:0]];
//        }
//        else
//        {
//            [self setPhoneCurrentRingtoneName:localSelectedRingtone];
//            [self setPhoneCurrentRingtoneIndex:[NSIndexPath indexPathForRow:0 inSection:0]];            
//        }
    }
    
    return self;
}


- (void)SavantCallSeverFound:(NSNotification *)notification
{
//    if ([self isRPMPhoneServiceEnabled])
//    {
//        [rpmLogEvent log:@"SAVANT PBX FOUND" object:[[notification userInfo] objectForKey:@"AsteriskIpAddress"]];
//    
//    }
//    else
//    {
//        [rpmLogEvent log:@"SAVANT CALL SERVER FOUND" object:[[notification userInfo] objectForKey:@"AsteriskIpAddress"]];
//    }
    
    [self setupDefaultsWithContentsOfConfigurationFile:self.telephonyEndPoints andRegistrarIpAddress:@"10.5.225.19"];
//
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    
    NSArray *savedAccounts = [defaults arrayForKey:kAccounts];
//    if([savedAccounts count] == 0)
//    {
//        [rpmLogEvent log:@"Account for TP not found, please review configuration" object:nil];
//
//        return;
//    }
//    NSDictionary *accountDict = [savedAccounts objectAtIndex:0];
//    NSString *registrar;
//    if ([[accountDict objectForKey:kRegistrar] length] > 0)
//        registrar = [accountDict objectForKey:kRegistrar];
//    else
//        registrar = [accountDict objectForKey:kDomain];
//    
//    
//    [rpmLogEvent log:[NSString stringWithFormat:@"Savant Call Server = %@ %@ %d", registrar, [[notification userInfo] objectForKey:@"AsteriskIpAddress"] , [savedAccounts count]   ] object:nil];
//
//    
//    rpmPadControllerAppDelegate *appDelegate = (rpmPadControllerAppDelegate *)[[UIApplication sharedApplication] delegate];

    [[self telephone] setOutboundProxyHost:
     [defaults stringForKey:kOutboundProxyHost]];
    
    [[self telephone] setOutboundProxyPort:
     [defaults integerForKey:kOutboundProxyPort]];
    
    [[self telephone] setSTUNServerHost:
     [defaults stringForKey:kSTUNServerHost]];
    
    [[self telephone] setSTUNServerPort:[defaults integerForKey:kSTUNServerPort]];
    
//    [[self telephone] setUserAgentString:[NSString stringWithFormat:@"%@ (pjsip %@)", 
//                                          [appDelegate getVersion], [NSString stringWithCString:PJ_VERSION encoding:NSUTF8StringEncoding]]];
    
    [[self telephone] setLogFileName:[defaults stringForKey:kLogFileName]];
    
    if([defaults integerForKey:kLogLevel])
    {
        [[self telephone] setLogLevel:[defaults integerForKey:kLogLevel]];
    }
    
    if([defaults integerForKey:kConsoleLogLevel])
    {
        [[self telephone] setConsoleLogLevel:
         [defaults integerForKey:kConsoleLogLevel]];
    }
    
    [[self telephone] setDetectsVoiceActivity:
     [defaults boolForKey:kVoiceActivityDetection]];
    
    [[self telephone] setUsesICE:[defaults boolForKey:kUseICE]];
    
    [[self telephone] setTransportPort:[defaults integerForKey:kTransportPort]];
    
    [[self telephone] setTransportPublicHost:
     [defaults stringForKey:kTransportPublicHost]];
    
    //[self setRingtone:[NSSound soundNamed:
    //                   [defaults stringForKey:kRingingSound]]];
    

    
    // Setup an account on first launch.
    if ([savedAccounts count] == 0) {
        // There are no saved accounts, prompt user to add one.
        return;
    }
    
    //Init the remote endpoint List with ip phones and door entry systems if any
    // this will allow the devices to show up
    //[self initDeviceListWithConfiguration];
    
    // There are saved accounts, open account windows.
    for (NSUInteger i = 0; i < [savedAccounts count]; ++i) {
        NSDictionary *accountDict = [savedAccounts objectAtIndex:i];
        
        NSString *fullName = [accountDict objectForKey:kFullName];
        
        NSString *SIPAddress;
        if ([[accountDict objectForKey:kSIPAddress] length] > 0) {
            SIPAddress = [accountDict objectForKey:kSIPAddress];
        } else {
            SIPAddress = [NSString stringWithFormat:@"%@@%@",
                          [accountDict objectForKey:kUsername],
                          [accountDict objectForKey:kDomain]];
        }
        
        NSString *registrar;
        if ([[accountDict objectForKey:kRegistrar] length] > 0)
            registrar = [accountDict objectForKey:kRegistrar];
        else
            registrar = [accountDict objectForKey:kDomain];
        
        NSString *realm = [accountDict objectForKey:kRealm];
        NSString *username = [accountDict objectForKey:kUsername];
        NSString *password = [accountDict objectForKey:kAccountPassword];
        NSNumber *dontShow = [accountDict objectForKey:@"DontShowOnRemoteDevices"];
        NSNumber *showAll     = [accountDict objectForKey:@"ShowAllDevices"];
        NSNumber *registrarNeeded     = [accountDict objectForKey:@"RegistrarNeeded"];
        

        TelephonyAccountController *anAccountController
        = [[TelephonyAccountController alloc] initWithFullName:fullName
                                            SIPAddress:SIPAddress
                                             registrar:registrar
                                                 realm:realm
                                              username:username password:password registrarNeeded:[registrarNeeded boolValue]];
        
        [anAccountController setAppController:self];
        [anAccountController setAttemptingToRegisterAccount:YES];
        [anAccountController setEndpointDontShow:[dontShow boolValue]];
        [anAccountController setEndpointShowAll:[showAll boolValue]];
//        [anAccountController telephonyAccountControllerPostStateToStateCenter:kStateCenterTelephonyCallState withValue:kStateCenterTelephonyRegistrationStateNotRegistered];

        //Lets see if this device has global call server enabled
//        if ([self isGlobalCallServerFromConfigFileForEndpoint:[rpmDeviceUtils deviceUID]])
//        {
//            //global call server is enabled so we:
//            //MUST use bonjour to publish our info
//            [_service bonjourPublish:fullName registrar:registrar username:username telephonyDontShow:dontShow telephonyShowAll:showAll];
//            
//            //Start browsing for  savant endpoints            
//            [_service bonjourStartBrowsing];
//        }
//        else 
//        {
//            // the global Call Server is disabled for this device
//            // we dont publish or self and dont browse for remote endpoints
//        }
        
        [[anAccountController account] setReregistrationTime:
         [[accountDict objectForKey:kReregistrationTime] integerValue]];
        
        if ([[accountDict objectForKey:kUseProxy] boolValue]) {
            [[anAccountController account] setProxyHost:
             [accountDict objectForKey:kProxyHost]];
            [[anAccountController account] setProxyPort:
             [[accountDict objectForKey:kProxyPort] integerValue]];
        }
        
//        [anAccountController setEnabled:
//         [[accountDict objectForKey:kAccountEnabled] boolValue]];
//        [anAccountController setSubstitutesPlusCharacter:
//         [[accountDict objectForKey:kSubstitutePlusCharacter] boolValue]];
//        [anAccountController setPlusCharacterSubstitution:
//         [accountDict objectForKey:kPlusCharacterSubstitutionString]];
//		
//		//YZhou
////        [self telephonySLAInitialization:[anAccountController account] accountData:accountDict];
//        
//        //Bug 24992
//        [[self accountControllers] removeAllObjects]; // we only support 1 account
//        [[self accountControllers] addObject:anAccountController];
//        NSLog(@"adding Controller %@ to AppController", anAccountController );
//        
//        if (![anAccountController isEnabled]) {
//            // Prevent conflict with |setFrameAutosaveName:| when enabling
//            // the account.
//            //[anAccountController setWindow:nil];
//            
//            continue;
//        }
        
    }
    
//    [self initDeviceListWithConfiguration];
    
    if (1)//(isAnythingReachable)
    {
        // Show error if SIP user agent launch fails.
          
//        [self setShouldRegisterAllAccounts:YES];
//        if([self isRPMPhoneServiceEnabled])
        {
            if ( [[self telephone] userAgentState] ==  kAKTelephoneUserAgentStopped)
            {
                [[self telephone] startUserAgent];
            }
            else 
            {
                NSNotification *notification
                = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStartingNotification
                                                object:[self telephone]];
                
                [[NSNotificationCenter defaultCenter]
                 performSelectorOnMainThread:@selector(postNotification:)
                 withObject:notification
                 waitUntilDone:NO];
                
            }
        }
//        else 
//        {
//            if ( [[self telephone] userAgentState] ==  kAKTelephoneUserAgentStopped)
//            {
//                [[self telephone] startUserAgent];
//            }
//            else 
//            {
//                NSNotification *notification
//                = [NSNotification notificationWithName:AKTelephoneUserAgentDidFinishStartingNotification
//                                                object:[self telephone]];
//                
//                [[NSNotificationCenter defaultCenter]
//                 performSelectorOnMainThread:@selector(postNotification:)
//                 withObject:notification
//                 waitUntilDone:NO];
//                
//            }
        
//            [[self telephone] startUserAgent];
//        }
    }
}

-(void)remoteEndpointsAlloc
{
    self.remoteEndPoints =[[NSMutableDictionary alloc] initWithCapacity:(NSUInteger)72]; //max allowed 72 endpoints
}

- (void)_telephonyApplicationDidFinishLaunching:(NSNotification *)aNotification
{
//    if([self _isSIPAllowed])
    {
        // Bug 21478
        // we set the sounds to use here.at this point we know wether the phone or inetrcom service is running
//        [self telephonyAppControllerSetSoundFiles];
        
        /*
         * AOB : start browsing for the server, else we dont do anything.
         * we only use bonjour when the connection type is bonjour
         * now we can connet directly using an ipaddress from the configuration
         */
//        if ([self isBonjourConnectionAllowed])
//        {
//            [rpmLogEvent log:@"Browsing for Call Server....." object:nil];
//            [_service bonjourCallServerDealloc];
//            _service = [[TelephonyBonjour alloc] initWithRemoteEndPoints:nil   bonjourtype:[self getBonjourTypeFromConfigFile]];
//            [_service bonjourStartBrowsingForCallServer];
//        }
//        else
//        {
//            _service = [[TelephonyBonjour alloc] initWithRemoteEndPoints:nil   bonjourtype:[self getBonjourTypeFromConfigFile]];
//            [rpmLogEvent log:@"Connecting to Telephony Server....." object:[self getTelephonyServerHostName]];
//            NSDictionary *d = [NSDictionary dictionaryWithObject:[self getTelephonyServerHostName] forKey:@"AsteriskIpAddress"];
//            [[NSNotificationCenter defaultCenter] postNotificationName:@"Savant_AsteriskFound" object:self userInfo:d];
//        }
    }
//    else
//    {
//        [rpmLogEvent log:@"Telephony/SIP not configured for this endpoint, check BP" object:nil];
//    }
}

- (void)setupDefaultsWithContentsOfConfigurationFile:(NSDictionary *)settingsDict andRegistrarIpAddress:(NSString *)bonjourRegistrar
{
    //NSDictionary *settingsDict  = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (settingsDict == nil)
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //remove the accounts since we will recreate them using the plist coming from blueprint
    //[defaults removeObjectForKey:kAccounts];
    //[defaults synchronize];
    
    NSNumber *useDNSSRV = [settingsDict objectForKey:kUseDNSSRV];
    if (useDNSSRV != nil) {
        [defaults setBool:[useDNSSRV boolValue] forKey:kUseDNSSRV];
    }
    
    NSString *outboundProxyHost = [settingsDict objectForKey:kOutboundProxyHost];
    if (outboundProxyHost != nil) {
        [defaults setObject:outboundProxyHost forKey:kOutboundProxyHost];
    }
    
    NSNumber *outboundProxyPort = [settingsDict objectForKey:kOutboundProxyPort];
    if (outboundProxyPort != nil) {
        [defaults setInteger:[outboundProxyPort integerValue]
                      forKey:kOutboundProxyPort];
    }
    
    NSString *STUNServerHost = [settingsDict objectForKey:kSTUNServerHost];
    if (STUNServerHost != nil) {
        [defaults setObject:STUNServerHost forKey:kSTUNServerHost];
    }
    
    NSNumber *STUNServerPort = [settingsDict objectForKey:kSTUNServerPort];
    if (STUNServerPort != nil) {
        [defaults setInteger:[STUNServerPort integerValue]
                      forKey:kSTUNServerPort];
    }
    
    NSString *logFileName = [settingsDict objectForKey:kLogFileName];
    if (logFileName != nil) {
        [defaults setObject:logFileName forKey:kLogFileName];
    }
    
    NSNumber *logLevel = [settingsDict objectForKey:kLogLevel];
    if (logLevel != nil) {
        [defaults setInteger:[logLevel integerValue] forKey:kLogLevel];
    }
    
    NSNumber *consoleLogLevel = [settingsDict objectForKey:kConsoleLogLevel];
    if (consoleLogLevel != nil) {
        [defaults setInteger:[consoleLogLevel integerValue]
                      forKey:kConsoleLogLevel];
    }
    
    NSNumber *voiceActivityDetection
    = [settingsDict objectForKey:kVoiceActivityDetection];
    if (voiceActivityDetection != nil) {
        [defaults setBool:[voiceActivityDetection boolValue]
                   forKey:kVoiceActivityDetection];
    }
    
    NSNumber *useICE = [settingsDict objectForKey:kUseICE];
    if (useICE != nil) {
        [defaults setBool:[useICE boolValue] forKey:kUseICE];
    }
    
    NSNumber *transportPort = [settingsDict objectForKey:kTransportPort];
    if (transportPort != nil) {
        [defaults setInteger:[transportPort integerValue] forKey:kTransportPort];
    }
    else
    {
        [defaults setInteger:kAKDefaultSIPProxyPort forKey:kTransportPort];
    }
	
    NSDictionary *gateway = [settingsDict objectForKey:@"Gateway"];
	NSNumber *version = [settingsDict objectForKey:@"Version"];
    //
    [defaults setBool:TRUE forKey:kAutoCloseCallWindow];
    [defaults setObject:@"2999" forKey:@"VoicemailNumber"];
    
    NSArray *endpoints = [settingsDict objectForKey:@"Endpoints"];
    NSMutableArray *validEndpoints  = [NSMutableArray arrayWithCapacity:[endpoints count]];
//    [rpmLogEvent log:[NSString stringWithFormat:@"Looking Confguration for UID [%@]", [[rpmDeviceUtils deviceUID] lowercaseString]    ] object:nil];
    if (endpoints != nil)
    {
        BOOL endpointValid = NO;
        
        for(NSDictionary *anEndpoint in endpoints)
        {
            if ([[anEndpoint objectForKey:kFullName] length] > 0 &&
                [[anEndpoint objectForKey:kDomain] length] > 0 &&
                [[anEndpoint objectForKey:kUsername] length] > 0 &&
                [anEndpoint objectForKey:kAccountPassword] != nil)
            {
                endpointValid = YES;
            }
            
            NSString *endPointUID = [anEndpoint objectForKey:@"SavantUID"];
            /*
             * AOB:Here from 4.2 we will use the UserDefinedName to check instead of the UID
             * this is because the flex iPad support....
             */
//            if (endpointValid && endPointUID && [[endPointUID  lowercaseString]  isEqualToString:[[rpmDeviceUtils deviceUID] lowercaseString] ])
            {
                NSMutableDictionary *aValidEndpoint  = [NSMutableDictionary dictionaryWithDictionary:anEndpoint];
                
                //AOB
                [aValidEndpoint setObject:bonjourRegistrar forKey:kRegistrar];
                [aValidEndpoint setObject:bonjourRegistrar forKey:kDomain];
                [aValidEndpoint setObject:@"*" forKey:kRealm];
                [aValidEndpoint setObject:[NSNumber numberWithBool:YES] forKey:kAccountEnabled];
                [aValidEndpoint setObject:[NSString stringWithFormat:@"endpoint<%@>",[anEndpoint objectForKey:kFullName]]  forKey:kDescription];
                if ([anEndpoint objectForKey:@"DontShowOnRemoteDevices"])
                {
                    [aValidEndpoint setObject:[anEndpoint objectForKey:@"DontShowOnRemoteDevices"] forKey:@"DontShowOnRemoteDevices"];
                }
                else
                {
                    [aValidEndpoint setObject:[NSNumber numberWithBool:NO] forKey:@"DontShowOnRemoteDevices"];
                }
                if ([anEndpoint objectForKey:@"ShowAllDevices"])
                {
                    [aValidEndpoint setObject:[anEndpoint objectForKey:@"ShowAllDevices"] forKey:@"ShowAllDevices"];
                }
                else
                {
                    [aValidEndpoint setObject:[NSNumber numberWithBool:NO] forKey:@"ShowAllDevices"];
                }
                if ([anEndpoint objectForKey:@"RegistrarNeeded"])
                {
                    [aValidEndpoint setObject:[anEndpoint objectForKey:@"RegistrarNeeded"] forKey:@"RegistrarNeeded"];
                }
                else
                {
                    [aValidEndpoint setObject:[NSNumber numberWithBool:YES] forKey:@"RegistrarNeeded"];
                }
                NSDictionary *line;
				if([version intValue] >= 2)
                {
                    NSArray *gateways = [settingsDict objectForKey:@"Gateways"];
                    if(gateways && [gateways count])
                    {
                        for(NSDictionary *gatewayDict in gateways)
                        {
                            int gatewayIndex;
                            if([gatewayDict objectForKey:@"GatewayIndex"])
                            {
                                gatewayIndex = [[gatewayDict objectForKey:@"GatewayIndex"]intValue];
                                if(!gatewayIndex)
                                {
                                    gatewayIndex = 1;
                                }
                            }
                            else
                            {
                                gatewayIndex = 1;
                            }
                            if(gatewayIndex >= 1 && gatewayIndex <= kTelephonyMaxNumberOfGateways)
                            {
                                NSDictionary *linesDict = [gatewayDict objectForKey:@"Lines"];
                                if(linesDict)
                                {
                                    NSArray *lineKeys = [linesDict allKeys];
                                    for (NSString *key in lineKeys)
                                    {
                                        [aValidEndpoint setObject:[linesDict objectForKey:key] forKey:[[linesDict objectForKey:key]objectForKey:@"Name"]];
                                    }
                                }
                            }
                        }
                    }
                }
                else
                {
                    if(gateway)// && [self isRPMPhoneServiceEnabled] )
                    {
                        for(int i = 1; i <= 4; i++)
                        {
                            line = [gateway objectForKey:[NSString stringWithFormat:@"Line%d", i]];
                            if(line)
                            {
                                [aValidEndpoint setObject:line forKey:[NSString stringWithFormat:@"Line%d", i]];
                            }
                        }
                    }
                }
                [validEndpoints addObject:aValidEndpoint];
            }
        }
        
        // Add valid accounts to the existings accounts.
        //NSArray *currentAccounts = [defaults arrayForKey:kAccounts];
        //NSMutableArray *newAccounts
        //= [NSMutableArray arrayWithArray:currentAccounts];
        //[newAccounts addObjectsFromArray:validEndpoints];
        [defaults setObject:validEndpoints forKey:kAccounts];
    }
    
	[defaults synchronize];
}

- (void)telephonyApplicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self _telephonyApplicationDidFinishLaunching:nil];
}

@end