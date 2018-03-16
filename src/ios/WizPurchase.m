/* WizPurchase
 *
 * @author Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file WizPurchase.m
 *
 */

#import "WizPurchase.h"
#import "WizDebugLog.h"

@implementation WizPurchase

- (void)pluginInitialize {
    applicationUsername = nil;

    restoredTransactions = [[NSMutableArray alloc] init];
    pendingTransactions = [[NSMutableDictionary alloc] init];

    restorePurchaseCallbacks = [[NSMutableArray alloc] init];
    refreshReceiptCallbacks = [[NSMutableDictionary alloc] init];

    // Register ourselves as a transaction observer
    // (we get notified when payments in the payment queue get updated)
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)restoreAllPurchases:(CDVInvokedUrlCommand *)command {
    WizLog(@"Restoring purchase");

    [restorePurchaseCallbacks addObject:command.callbackId];
    // If there is more than one restore purchase callback waiting it means a restore purchase request was already sent
    if ([restorePurchaseCallbacks count] > 1) {
        return;
    }

    // Call this to get any previously purchased non-consumables
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)getProductDetails:(CDVInvokedUrlCommand *)command {
    WizLog(@"Getting products details");
    
    getProductDetailsCb = command.callbackId;
    [self.commandDelegate runInBackground:^{
        [self fetchProducts:[command.arguments objectAtIndex:0]];
    }];
}

- (void)finishPurchase:(CDVInvokedUrlCommand *)command {
    // Remove any transaction(s) we have verified with a server from pending transactions matching productId
    NSString *productId = [command.arguments objectAtIndex:0];
    SKPaymentTransaction *transaction = [pendingTransactions objectForKey:productId];
    if (!transaction) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsInt:PURCHASE_NOT_PENDING];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    [pendingTransactions removeObjectForKey:productId];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getPendingPurchases:(CDVInvokedUrlCommand *)command {
    [self sendTransactions:[pendingTransactions allValues] toCallback:command.callbackId];
}

- (void)setApplicationUsername:(CDVInvokedUrlCommand *)command {
    applicationUsername = [command.arguments objectAtIndex:0];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)purchaseProduct:(SKProduct *)product {
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    if ([applicationUsername length] != 0) {
        payment.applicationUsername = applicationUsername;
    }
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

- (void)sendTransactionResultsWithReceipt:(NSArray *)results toCallback:(NSString *)callbackId {
    // Best practice of weak linking using the respondsToSelector: cannot be used here
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsInt:IOS_VERSION_ERR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        return;
    }
    NSString *receiptString = [self getReceiptString];
    if (receiptString) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                           messageAsArray:[self addReceiptToTransactionResults:receiptString results:results]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    } else {
        [self refreshReceipt:callbackId result:results];
    }
}

- (void)sendTransactionResultWithReceipt:(NSDictionary *)result toCallback:(NSString *)callbackId {
    // Best practice of weak linking using the respondsToSelector: cannot be used here
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsInt:IOS_VERSION_ERR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        return;
    }
    NSString *receiptString = [self getReceiptString];
    if (receiptString) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:[self addReceiptToTransactionResult:receiptString result:result]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    } else {
        [self refreshReceipt:callbackId result:result];
    }
}

- (void)sendTransaction:(SKPaymentTransaction *)transaction toCallback:(NSString *)callbackId {
    [self sendTransactionResultWithReceipt:[self buildTransactionResult:transaction] toCallback:callbackId];
}

- (void)sendTransactions:(NSArray *)transactions toCallback:(NSString *)callbackId {
    NSMutableArray *transactionResults = [[NSMutableArray alloc] init];
    for (SKPaymentTransaction *transaction in transactions) {
        [transactionResults addObject:[self buildTransactionResult:transaction]];
    }
    [self sendTransactionResultsWithReceipt:transactionResults toCallback:callbackId];
}

- (void)refreshReceipt:(NSString *)callbackId result:(id)result {
    [refreshReceiptCallbacks setObject:result forKey:callbackId];
    // If there is more than one refresh receipt callback waiting it means a receipt refresh request was already sent
    if ([refreshReceiptCallbacks count] > 1) {
        return;
    }
    SKReceiptRefreshRequest *receiptRefreshRequest = [[SKReceiptRefreshRequest alloc] init];
    receiptRefreshRequest.delegate = self;
    [receiptRefreshRequest start];
}

- (void)refreshReceipt:(CDVInvokedUrlCommand *)command {
    [self refreshReceipt:command.callbackId result:[NSNull null]];
}

- (void)fetchProducts:(NSArray *)productIdentifiers {
    WizLog(@"Fetching product information");
    // Build a SKProductsRequest for the identifiers provided
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
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
    NSArray *callbackIds = [refreshReceiptCallbacks allKeys];
    if (receipt) {
        for (NSString *callbackId in callbackIds) {
            id result = [refreshReceiptCallbacks objectForKey:callbackId];
            if ([result isKindOfClass:[NSDictionary class]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                             messageAsDictionary:[self addReceiptToTransactionResult:receipt result:result]];
            } else if ([result isKindOfClass:[NSArray class]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                  messageAsArray:[self addReceiptToTransactionResults:receipt results:result]];
            } else if ([result isEqual:[NSNull null]]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                            messageAsInt:INVALID_RECEIPT];
        for (NSString *callbackId in callbackIds) {
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    }
    [refreshReceiptCallbacks removeAllObjects];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    WizLog(@"request - didFailWithError: %@", [[error userInfo] objectForKey:@"NSLocalizedDescription"]);
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        [self receiptRefreshRequest:(SKReceiptRefreshRequest *)request didFailWithError:error];
    }
}

- (void)receiptRefreshRequest:(SKReceiptRefreshRequest *)request didFailWithError:(NSError *)error {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                         messageAsInt:RECEIPT_REFRESH_FAILED];
    NSArray * keys = [refreshReceiptCallbacks allKeys];
    for (NSString *key in keys) {
        [self.commandDelegate sendPluginResult:pluginResult callbackId:key];
    }
    [refreshReceiptCallbacks removeAllObjects];
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
                                                                 messageAsInt:UNKNOWN_PRODUCT_ID];
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
                                                             messageAsInt:UNKNOWN_PRODUCT_ID];
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
                                                                 messageAsInt:UNKNOWN_PRODUCT_ID];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:getProductDetailsCb];
            getProductDetailsCb = NULL;
            return;
        }
       
        // If you request all productIds we create a shortcut here for doing makePurchase
        // it saves on http requests
        validProducts = response.products;
        
        NSDictionary *product = NULL;
        NSMutableDictionary *productsDictionary = [[NSMutableDictionary alloc] init];
        WizLog(@"Products found: %tu", [validProducts count]);
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

- (NSDictionary *)buildTransactionResult:(SKPaymentTransaction *)transaction {
    return @{
             @"platform": @"ios",
             @"orderId": transaction.transactionIdentifier,
             @"productId": transaction.payment.productIdentifier,
             @"packageName": [[NSBundle mainBundle] bundleIdentifier]
             };
}

# pragma Methods for SKPaymentTransactionObserver

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    for (NSString *callbackId in restorePurchaseCallbacks) {
        [self sendTransactions:[restoredTransactions copy] toCallback:callbackId];
    }

    [restoredTransactions removeAllObjects];
    [restorePurchaseCallbacks removeAllObjects];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    // Convert error code to String
    int errorString = [self returnErrorCode:error];
    // Return result to JavaScript
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                         messageAsInt:errorString];
    for (NSString* callbackId in restorePurchaseCallbacks) {
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }

    [restoredTransactions removeAllObjects];
    [restorePurchaseCallbacks removeAllObjects];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {

    NSInteger errorCode = 0; // Set default unknown error
    NSString *error;
    for (SKPaymentTransaction *transaction in transactions) {
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                WizLog(@"SKPaymentTransactionStatePurchasing");
                break;
            case SKPaymentTransactionStateDeferred:
                WizLog(@"SKPaymentTransactionStateDeferred");
                break;
            case SKPaymentTransactionStatePurchased: {
                WizLog(@"SKPaymentTransactionStatePurchased");
                if (makePurchaseCb) {
                    [self sendTransaction:transaction toCallback:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                [pendingTransactions setObject:transaction forKey:transaction.payment.productIdentifier];
                break;
            }
            case SKPaymentTransactionStateRestored:
                // We restored some non-consumable transactions
                WizLog(@"SKPaymentTransactionStateRestored");
                if ([restorePurchaseCallbacks count] > 0) {
                    [restoredTransactions addObject:transaction];
                }
                [pendingTransactions setObject:transaction forKey:transaction.payment.productIdentifier];
                break;
            case SKPaymentTransactionStateFailed:
                error = transaction.error.localizedDescription;
                errorCode = transaction.error.code;
                WizLog(@"SKPaymentTransactionStateFailed %zd %@", errorCode, error);
                if (makePurchaseCb) {
                    // Return result to JavaScript
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                         messageAsInt:[self returnErrorCode:transaction.error]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            default:
                WizLog(@"Invalid transaction state: %zd", transaction.transactionState);
                if (makePurchaseCb) {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                         messageAsInt:INVALID_TRANSACTION_STATE];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:makePurchaseCb];
                    makePurchaseCb = NULL;
                    makePurchaseProductId = NULL;
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
        }
    }
}

- (int)returnErrorCode:(NSError *)error {
    // Default error SKErrorUnknown
    int errorString = UNKNOWN_ERROR;
    // Indicates that an unknown or unexpected error occurred.
    if ([error.domain isEqualToString:@"SKErrorDomain"]) {
        switch (error.code) {
            case SKErrorClientInvalid:
                // Indicates that the client is not allowed to perform the attempted action.
                errorString = INVALID_CLIENT;
                break;
            case SKErrorPaymentCancelled:
                // Indicates that the user cancelled a payment request.
                errorString = USER_CANCELLED;
                break;
            case SKErrorPaymentInvalid:
                // Indicates that one of the payment parameters was not recognized by the Apple App Store.
                errorString = INVALID_PAYMENT;
                break;
            case SKErrorPaymentNotAllowed:
                // Indicates that the user is not allowed to authorise payments.
                errorString = UNAUTHORIZED;
                break;
            case SKErrorStoreProductNotAvailable:
                // Indicates that the requested product is not available in the store.
                errorString = UNKNOWN_PRODUCT_ID;
                break;
            default:
                break;
        }
    }
    return errorString;
}

@end
