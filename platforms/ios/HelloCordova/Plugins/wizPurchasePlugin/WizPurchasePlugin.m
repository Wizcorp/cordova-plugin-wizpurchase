/* wizPurchasePlugin
 *
 * @author Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file wizPurchasePlugin.m
 *
 */

#import "WizPurchasePlugin.h"
#import "WizDebugLog.h"

@implementation WizPurchasePlugin

- (CDVPlugin *)initWithWebView:(UIWebView *)theWebView {

    if (self) {
        // Register ourselves as a transaction observer
        // (we get notified when payments in the payment queue get updated)
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (BOOL)canMakePurchase {
    return [SKPaymentQueue canMakePayments];
}

- (void)canMakePurchase:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        CDVPluginResult *pluginResult;
        if ([self canMakePurchase]) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"unknownProductId"];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)restoreAll:(CDVInvokedUrlCommand *)command {
    WizLog(@"Restoring purchase");

    restorePurchaseCb = command.callbackId;
    // [self.commandDelegate runInBackground:^{
        // Call this to get any previously purchased non-consumables
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    // }];
}

- (void)getProductDetail:(CDVInvokedUrlCommand *)command {
    WizLog(@"Getting products details");
    
    getProductDetailsCb = command.callbackId;
    [self.commandDelegate runInBackground:^{
        [self fetchProducts:[command.arguments objectAtIndex:0]];
    }];
}

- (void)consumePurchase:(CDVInvokedUrlCommand *)command {
    // Remove any receipt(s) from NSUserDefaults matching productIds, we have verified with a server
    NSArray *productIds = [command.arguments objectAtIndex:0];
    for (NSString *productId in productIds) {
        // Remove receipt from storage
        [self removeReceipt:productId];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getPending:(CDVInvokedUrlCommand *)command {
    // Return contents of user defaults
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                       messageAsArray:[self fetchReceipts]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)purchaseProduct:(SKProduct *)product {
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (SKProduct *)findProductInProducts:(NSArray *)products productId:(NSString *)productId {
    if (products == NULL) {
        return NULL;
    }

    SKProduct *product = NULL;
    for (SKProduct *obj in products) {
        if ([obj.productIdentifier isEqualToString:productId]) {
            product = obj;
            break;
        }
    }
    return product;
}

- (void)makePurchase:(CDVInvokedUrlCommand *)command {
    makePurchaseProductId = [command.arguments objectAtIndex:0];
    makePurchaseCb = command.callbackId;

    SKProduct *product = [self findProductInProducts:validProducts productId:makePurchaseProductId];
    
    [self.commandDelegate runInBackground:^{
        if (product != NULL) {
            [self purchaseProduct:product];
        } else {
            // We need to fetch the product
            [self fetchProducts:@[ makePurchaseProductId ]];
        }
    }];
}

- (void)fetchProducts:(NSArray *)productIdentifiers {
    WizLog(@"Fetching product information");
    // Build a SKProductsRequest for the identifiers provided
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (NSArray *)fetchReceipts {
    WizLog(@"Fetching receipts");
#if USE_ICLOUD_STORAGE
    NSUbiquitousKeyValueStore *storage = [NSUbiquitousKeyValueStore defaultStore];
#else
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
#endif
    
    NSArray *savedReceipts = [storage arrayForKey:@"receipts"];
    if (!savedReceipts) {
        // None found
        return @[ ];
    } else {
        // Return array
        return savedReceipts;
    }
}

- (void)removeReceipt:(NSString *)productId {
    WizLog(@"Removing receipt for productId");
#if USE_ICLOUD_STORAGE
    NSUbiquitousKeyValueStore *storage = [NSUbiquitousKeyValueStore defaultStore];
#else
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
#endif

    NSMutableArray *savedReceipts = [[NSMutableArray alloc] initWithArray:[storage objectForKey:@"receipts"]];
    if (savedReceipts) {
        for (int i = 0; i < [savedReceipts count]; i++) {
            if ([[[NSDictionary dictionaryWithDictionary:[savedReceipts objectAtIndex:i]] objectForKey:@"productId"] isEqualToString:productId]) {
                // Remove receipt with matching productId
                [savedReceipts removeObject:[savedReceipts objectAtIndex:i]];
                // Remove old receipt array and switch for new one
                [storage removeObjectForKey:@"receipts"];
                [storage setObject:savedReceipts forKey:@"receipts"];
                [storage synchronize];
            }
        }
    }
}

- (void)backupReceipt:(NSDictionary *)result {
    WizLog(@"Backing up receipt");
#if USE_ICLOUD_STORAGE
    NSUbiquitousKeyValueStore *storage = [NSUbiquitousKeyValueStore defaultStore];
#else
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
#endif
    
    NSArray *savedReceipts = [storage arrayForKey:@"receipts"];
    if (!savedReceipts) {
        // Storing the first receipt
        [storage setObject:@[result] forKey:@"receipts"];
    } else {
        // Adding another receipt
        NSArray *updatedReceipts = [savedReceipts arrayByAddingObject:result];
        [storage setObject:updatedReceipts forKey:@"receipts"];
    }
    [storage synchronize];
}

# pragma Methods for SKProductsRequestDelegate

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    WizLog(@"request - didFailWithError: %@", [[error userInfo] objectForKey:@"NSLocalizedDescription"]);
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    // Receiving a list of products from Apple
    
    if (makePurchaseCb != NULL) {
        
        if ([response.invalidProductIdentifiers count] > 0) {
            for (NSString *invalidProductId in response.invalidProductIdentifiers) {
                WizLog(@"Invalid product id: %@" , invalidProductId);
            }
            // We have requested at least one invalid product fallout here for security
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:@"unknownProductId"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
            makePurchaseCb = NULL;
            makePurchaseProductId = NULL;
            return;
        }
        
        // Continue the purchase flow
        SKProduct *product = [self findProductInProducts:response.products productId:makePurchaseProductId];
        if (product) {
            [self purchaseProduct:product];
            return;
        }
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"unknownProductId"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
        makePurchaseCb = NULL;
        makePurchaseProductId = NULL;
    }
    
    if (getProductDetailsCb != NULL) {
        // Continue product(s) list request
        
        if ([response.invalidProductIdentifiers count] > 0) {
            for (NSString *invalidProductId in response.invalidProductIdentifiers) {
                WizLog(@"Invalid product id: %@" , invalidProductId);
            }
            // We have requested at least one invalid product fallout here for security
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"unknownProductId"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:getProductDetailsCb];
            getProductDetailsCb = NULL;
            return;
        }
       
        // If you request all productIds we create a shortcut here for doing makePurchase
        // it saves on http requests
        validProducts = response.products;
        
        NSDictionary *product = NULL;
        NSMutableDictionary *productsDictionary = [[NSMutableDictionary alloc] init];
        WizLog(@"Products found: %i", [validProducts count]);
        NSString *storeCountry = NULL;
        NSString *storeCurrency = NULL;
        for (SKProduct *obj in validProducts) {
            // Build a detailed product list from the list of valid products
            
            // Fromat the price
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
            [numberFormatter setLocale:obj.priceLocale];
            NSString *formattedPrice = [numberFormatter stringFromNumber:obj.price];
            
            if (storeCountry == NULL || storeCurrency == NULL) {
                storeCountry = (NSString *)CFLocaleGetValue((CFLocaleRef)obj.priceLocale, kCFLocaleCountryCode);
                storeCurrency = [numberFormatter currencyCode];
            }

            product = @{
                @"name":        obj.localizedTitle,
                @"price":       formattedPrice,
                @"priceMicros": [[obj.price decimalNumberByMultiplyingByPowerOf10:6] stringValue],
                @"description": obj.localizedDescription
            };
            
            [productsDictionary setObject:product forKey:obj.productIdentifier];
        }
        
        NSDictionary *result = @{
                                 @"country":    storeCountry,
                                 @"currency":   storeCurrency,
                                 @"products":   productsDictionary
                                 };
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:result];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:getProductDetailsCb];
        getProductDetailsCb = NULL;
    }
}

# pragma Methods for SKPaymentTransactionObserver

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    if (restorePurchaseCb != NULL) {
        NSMutableArray *receipts = [[NSMutableArray alloc] init];
        if ([[[SKPaymentQueue defaultQueue] transactions] count] > 0) {
            for (SKPaymentTransaction *transaction in [[SKPaymentQueue defaultQueue] transactions]) {
                NSString *receipt = [[NSString alloc] initWithData:[transaction transactionReceipt] encoding:NSUTF8StringEncoding];
                NSDictionary *result = @{
                     @"platform": @"ios",
                     @"receipt": receipt,
                     @"productId": transaction.payment.productIdentifier,
                     @"packageName": [[NSBundle mainBundle] bundleIdentifier]
                };
                // Build array of restored receipt items
                [receipts addObject:result];
            }
        }

        // Return result to JavaScript
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                           messageAsArray:receipts];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:restorePurchaseCb];
        restorePurchaseCb = NULL;
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if (restorePurchaseCb != NULL) {
        // Convert error code to String
        NSString *errorString = [self returnErrorString:error];
        // Return result to JavaScript
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:errorString];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:restorePurchaseCb];
        restorePurchaseCb = NULL;
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {

	NSInteger errorCode = 0; // Set default unknown error
    NSString *error;
    for (SKPaymentTransaction *transaction in transactions) {
        
        switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchasing:
                WizLog(@"SKPaymentTransactionStatePurchasing");
				continue;
                
            { case SKPaymentTransactionStatePurchased:
                WizLog(@"SKPaymentTransactionStatePurchased");
                // Immediately save to NSUserDefaults incase we cannot reach JavaScript in time
                // or connection for server receipt verification is interupted
                NSString *receipt = [[NSString alloc] initWithData:[transaction transactionReceipt] encoding:NSUTF8StringEncoding];
                
                // We requested this payment let's finish
                NSDictionary *result = @{
                     @"platform": @"ios",
                     @"orderId": transaction.transactionIdentifier,
                     @"receipt": receipt,
                     @"productId": transaction.payment.productIdentifier,
                     @"packageName": [[NSBundle mainBundle] bundleIdentifier]
                };
                
                [self backupReceipt:result];

                if (makePurchaseCb) {
                   
                    // Return result to JavaScript
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                  messageAsDictionary:result];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                break;
            }
            case SKPaymentTransactionStateFailed:
            
				error = transaction.error.localizedDescription;
				errorCode = transaction.error.code;
				WizLog(@"SKPaymentTransactionStateFailed %d %@", errorCode, error);
                if (makePurchaseCb) {
                    // Return result to JavaScript
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:[self returnErrorString:transaction.error]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                break;
                
			case SKPaymentTransactionStateRestored: {
                // We restored some non-consumable transactions add to receipt backup
				WizLog(@"SKPaymentTransactionStateRestored");
                NSString *receipt = [[NSString alloc] initWithData:[transaction transactionReceipt] encoding:NSUTF8StringEncoding];
                NSDictionary *result = @{
                     @"platform": @"ios",
                     @"orderId": transaction.transactionIdentifier,
                     @"receipt": receipt,
                     @"productId": transaction.payment.productIdentifier,
                     @"packageName": [[NSBundle mainBundle] bundleIdentifier]
                };
				[self backupReceipt:result];
                break;
            }
            default:
				WizLog(@"SKPaymentTransactionStateInvalid");
                if (makePurchaseCb) {
                    // Return result to JavaScript
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:[self returnErrorString:transaction.error]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                continue;
        }
        
        // Finishing a transaction tells Store Kit that you’ve completed everything needed for the purchase.
        // Unfinished transactions remain in the queue until they’re finished, and the transaction queue
        // observer is called every time your app is launched so your app can finish the transactions.
        // Your app needs to finish every transaction, regardles of whether the transaction succeeded or failed.
		[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (NSString *)returnErrorString:(NSError *)error {
    // Default error SKErrorUnknown
    NSString *errorString = @"unknownError";
    // Indicates that an unknown or unexpected error occurred.
    if ([error.domain isEqualToString:@"SKErrorDomain"]) {
        switch (error.code) {
            case 1:
                // SKErrorClientInvalid
                // Indicates that the client is not allowed to perform the attempted action.
                errorString = @"invalidClient";
                break;
            case 2:
                // SKErrorPaymentCancelled
                // Indicates that the user cancelled a payment request.
                errorString = @"userCancelled";
                break;
            case 3:
                // SKErrorPaymentInvalid
                // Indicates that one of the payment parameters was not recognized by the Apple App Store.
                errorString = @"invalidPayment";
                break;
            case 4:
                // SKErrorPaymentNotAllowed
                // Indicates that the user is not allowed to authorise payments.
                errorString = @"unauthorized";
                break;
            case 5:
                // SKErrorStoreProductNotAvailable
                // Indicates that the requested product is not available in the store.
                errorString = @"unknownProductId";
                break;
            default:
                break;
        }
    }
    return errorString;
}

@end