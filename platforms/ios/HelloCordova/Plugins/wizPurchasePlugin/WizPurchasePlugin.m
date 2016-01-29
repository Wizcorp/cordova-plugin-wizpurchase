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

    refreshReceiptCallbacks = [[NSMutableDictionary alloc] init];

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
    [self sendTransactionResults:command.callbackId results:[self fetchReceipts]];
}

- (void)makePurchase:(CDVInvokedUrlCommand *)command {
    NSString *productId = [command.arguments objectAtIndex:0];
    makePurchaseCb = command.callbackId;
    
    SKProduct *product = NULL;
    if (productsResponse != NULL) {
        // We have a made a product request before, check if we already called for this product
        
        for (SKProduct *obj in (NSArray *)productsResponse.products) {
            // Look for our requested product in the list of valid products
            if ([obj.productIdentifier isEqualToString:productId]) {
                // Found a valid matching product
                product = obj;
                break;
            }
        }
    }
    
    [self.commandDelegate runInBackground:^{
        if (product != NULL) {
            // We can shortcut an HTTP request, this product has been requested before
            [self productsRequest:NULL didReceiveResponse:(SKProductsResponse *)productsResponse];
        } else {
            // We need to fetch the product
            [self fetchProducts:@[ productId ]];
        }
    }];
}

- (NSString *)getReceiptString {
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (!receiptData) {
        return nil;
    }
    return [receiptData base64EncodedStringWithOptions:0];
}

- (NSArray *)addReceiptToTransactionResults:(NSString *)receipt results:(NSArray *)results {
    NSMutableArray *transactionResults = [NSMutableArray arrayWithCapacity:[results count]];
    for (NSDictionary *result in results) {
        [transactionResults addObject:[self addReceiptToTransactionResult:receipt result:result]];
    }
    return transactionResults;
}

- (NSDictionary *)addReceiptToTransactionResult:(NSString *)receipt result:(NSDictionary *)result {
    NSMutableDictionary *resultWithReceipt = [result mutableCopy];
    [resultWithReceipt setValue:receipt forKey:@"receipt"];
    return resultWithReceipt;
}

- (void)getReceipt:(NSString *)callbackId results:(NSArray *)results {
    NSString *receiptString = [self getReceiptString];
    if (receiptString) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsArray:[self addReceiptToTransactionResults:receiptString results:results]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    } else {
        [self refreshReceipt:callbackId result:results];
    }
}

- (void)getReceipt:(NSString *)callbackId result:(NSDictionary *)result {
    NSString *receiptString = [self getReceiptString];
    if (receiptString) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:[self addReceiptToTransactionResult:receiptString result:result]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    } else {
        [self refreshReceipt:callbackId result:result];
    }
}

- (void)sendTransactionResult:(NSString *)callbackId result:(NSDictionary *)result {
    // Best practice of weak linking using the respondsToSelector: cannot be used here
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsInt:IOS_VERSION_ERR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        return;
    }
    [self getReceipt:callbackId result:result];
}

- (void)sendTransactionResults:(NSString *)callbackId results:(NSArray *)results {
    // Best practice of weak linking using the respondsToSelector: cannot be used here
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsInt:IOS_VERSION_ERR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        return;
    }
    [self getReceipt:callbackId results:results];
}

- (void)refreshReceipt:(NSString *)callbackId result:(id)result {
    if ([refreshReceiptCallbacks count] > 0) {
        [refreshReceiptCallbacks setObject:result forKey:callbackId];
        return;
    }
    SKReceiptRefreshRequest *receiptRefreshRequest = [[SKReceiptRefreshRequest alloc] init];
    receiptRefreshRequest.delegate = self;
    [receiptRefreshRequest start];
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

- (void) requestDidFinish:(SKRequest *)request {
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        [self receiptRefreshRequestDidFinish:(SKReceiptRefreshRequest *)request];
    }
}

- (void) receiptRefreshRequestDidFinish:(SKReceiptRefreshRequest *)request {
    CDVPluginResult *pluginResult;
    NSString *receipt = [self getReceiptString];
    NSArray * keys = [refreshReceiptCallbacks allKeys];
    if (receipt) {
        for (NSString *key in keys) {
            id result = [refreshReceiptCallbacks objectForKey:key];
            if ([result isKindOfClass:[NSDictionary class]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                             messageAsDictionary:[self addReceiptToTransactionResult:receipt result:result]];
            } else if ([result isKindOfClass:[NSArray class]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                  messageAsArray:[self addReceiptToTransactionResults:receipt results:result]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:key];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                            messageAsInt:INVALID_RECEIPT];
        for (NSString *key in keys) {
            [self.commandDelegate sendPluginResult:pluginResult callbackId:key];
        }
    }
    refreshReceiptCallbacks = [[NSMutableDictionary alloc] init];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    WizLog(@"request - didFailWithError: %@", [[error userInfo] objectForKey:@"NSLocalizedDescription"]);
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        [self receiptRefreshRequest:(SKReceiptRefreshRequest *)request didFailWithError:error];
    }
}

- (void)receiptRefreshRequest:(SKReceiptRefreshRequest *)request didFailWithError:(NSError *)error {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsString:[error localizedDescription]];
    NSArray * keys = [refreshReceiptCallbacks allKeys];
    for (NSString *key in keys) {
        [self.commandDelegate sendPluginResult:pluginResult callbackId:key];
    }
    refreshReceiptCallbacks = [[NSMutableDictionary alloc] init];
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
            return;
        }
        
        // Continue the purchase flow
        if ([response.products count] > 0) {
            SKProduct *product = [response.products objectAtIndex:0];
            SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
            
            return;
        }
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"unknownProductId"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
        makePurchaseCb = NULL;
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
        productsResponse = (SKProductsResponse *)response;
        
        NSDictionary *product = NULL;
        NSMutableDictionary *productsDictionary = [[NSMutableDictionary alloc] init];
        WizLog(@"Products found: %tu", [response.products count]);
        NSString *storeCountry = NULL;
        NSString *storeCurrency = NULL;
        for (SKProduct *obj in response.products) {
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
                NSDictionary *result = @{
                     @"platform": @"ios",
                     @"orderId": transaction.transactionIdentifier,
                     @"productId": transaction.payment.productIdentifier,
                     @"packageName": [[NSBundle mainBundle] bundleIdentifier]
                };
                // Build array of restored receipt items
                [receipts addObject:result];
            }
        }

        [self sendTransactionResults:restorePurchaseCb results:receipts];
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
                NSDictionary *result = @{
                                         @"platform": @"ios",
                                         @"orderId": transaction.transactionIdentifier,
                                         @"productId": transaction.payment.productIdentifier,
                                         @"packageName": [[NSBundle mainBundle] bundleIdentifier]
                                         };
                
                [self backupReceipt:result];

                if (makePurchaseCb) {
                    [self sendTransactionResult:makePurchaseCb result:result];
                    makePurchaseCb = NULL;
                }
                break;
            }
            case SKPaymentTransactionStateFailed:
            
				error = transaction.error.localizedDescription;
				errorCode = transaction.error.code;
				WizLog(@"SKPaymentTransactionStateFailed %zd %@", errorCode, error);
                if (makePurchaseCb) {
                    // Return result to JavaScript
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:[self returnErrorString:transaction.error]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                }
                break;
                
			case SKPaymentTransactionStateRestored: {
                // We restored some non-consumable transactions add to receipt backup
				WizLog(@"SKPaymentTransactionStateRestored");
                NSDictionary *result = @{
                     @"platform": @"ios",
                     @"orderId": transaction.transactionIdentifier,
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