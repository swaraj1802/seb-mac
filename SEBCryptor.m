//
//  SEBCryptor.m
//  SafeExamBrowser
//
//  Created by Daniel R. Schneider on 24.01.13.
//  Copyright (c) 2010-2013 Daniel R. Schneider, ETH Zurich,
//  Educational Development and Technology (LET),
//  based on the original idea of Safe Exam Browser
//  by Stefan Schneider, University of Giessen
//  Project concept: Thomas Piendl, Daniel R. Schneider,
//  Dirk Bauer, Karsten Burger, Marco Lehre,
//  Brigitte Schmucki, Oliver Rahs. French localization: Nicolas Dunand
//
//  ``The contents of this file are subject to the Mozilla Public License
//  Version 1.1 (the "License"); you may not use this file except in
//  compliance with the License. You may obtain a copy of the License at
//  http://www.mozilla.org/MPL/
//
//  Software distributed under the License is distributed on an "AS IS"
//  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
//  License for the specific language governing rights and limitations
//  under the License.
//
//  The Original Code is Safe Exam Browser for Mac OS X.
//
//  The Initial Developer of the Original Code is Daniel R. Schneider.
//  Portions created by Daniel R. Schneider are Copyright
//  (c) 2010-2013 Daniel R. Schneider, ETH Zurich, Educational Development
//  and Technology (LET), based on the original idea of Safe Exam Browser
//  by Stefan Schneider, University of Giessen. All Rights Reserved.
//
//  Contributor(s): ______________________________________.
//


#import "SEBCryptor.h"
#import "NSUserDefaults+SEBEncryptedUserDefaults.h"
#import "RNCryptor.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"

@implementation SEBCryptor

//@synthesize HMACKey = _HMACKey;

static SEBCryptor *sharedSEBCryptor = nil;

+ (SEBCryptor *)sharedSEBCryptor
{
	@synchronized(self)
	{
		if (sharedSEBCryptor == nil)
		{
			sharedSEBCryptor = [[self alloc] init];
		}
	}
    
	return sharedSEBCryptor;
}


// Method called when a value is written into the UserDefaults
// Calculates a checksum hash to 
- (void)updateEncryptedUserDefaults
{
    // Copy preferences to a dictionary
	NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    [preferences synchronize];
    NSDictionary *prefsDict;
    
    // Get CFBundleIdentifier of the application
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleId = [bundleInfo objectForKey: @"CFBundleIdentifier"];
    
    // Include UserDefaults from NSRegistrationDomain and the applications domain
    NSUserDefaults *appUserDefaults = [[NSUserDefaults alloc] init];
    [appUserDefaults addSuiteNamed:@"NSRegistrationDomain"];
    [appUserDefaults addSuiteNamed: bundleId];
    prefsDict = [appUserDefaults dictionaryRepresentation];
    
    // Filter dictionary so only org_safeexambrowser_SEB_ keys are included
    NSSet *filteredPrefsSet = [prefsDict keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop)
                               {
                                   if ([key hasPrefix:@"org_safeexambrowser_SEB_"])
                                       return YES;
                                   
                                   else return NO;
                               }];
    NSMutableDictionary *filteredPrefsDict = [NSMutableDictionary dictionaryWithCapacity:[filteredPrefsSet count]];
    // iterate keys and read all values
    (id)value;
    for (NSString *key in filteredPrefsSet) {
        value = [preferences secureObjectForKey:key];
        if (value == nil) value = NULL;
        [filteredPrefsDict setObject:value forKey:key];
    }
	NSMutableData *archivedPrefs = [[NSKeyedArchiver archivedDataWithRootObject:filteredPrefsDict] mutableCopy];

    // Generate and store salt for exam key
    NSData *HMACKey = [RNCryptor randomDataOfLength:kCCKeySizeAES256];
    [preferences setSecureObject:HMACKey forKey:@"org_safeexambrowser_SEB_examKeySalt"];

    NSMutableData *HMACData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];

    CCHmac(kCCHmacAlgSHA256, HMACKey.bytes, HMACKey.length, archivedPrefs.mutableBytes, archivedPrefs.length, [HMACData mutableBytes]);
    [preferences setValue:HMACData forKey:@"currentData"];
}

@end
