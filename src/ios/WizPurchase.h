/* WizPurchase
 *
 * @author Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file WizPurchase.h
 *
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <Cordova/CDVPlugin.h>

enum CDVWizPurchaseError {
    NO_ERROR = 0,
    UNKNOWN_ERROR = 1,
    ARGS_TYPE_MISMATCH = 2,
    ARGS_ARITY_MISMATCH = 3,
    IOS_VERSION_ERR = 4,
    INVALID_RECEIPT = 5,
    INVALID_TRANSACTION_STATE = 6,
    PURCHASE_NOT_FOUND = 7,
    PURCHASE_NOT_PENDING = 8,
    REMOTE_EXCEPTION = 9,
    BAD_RESPONSE= 10,
    BAD_SIGNATURE= 11,
    SEND_INTENT_FAILED = 12,
    USER_CANCELLED = 13,
    INVALID_PURCHASE = 14,
    MISSING_TOKEN = 15,
    NO_SUBSCRIPTIONS = 16,
    INVALID_CONSUMPTION = 17,
    CANNOT_PURCHASE = 18,
    UNKNOWN_PRODUCT_ID = 19,
    ALREADY_OWNED = 20,
    NOT_OWNED = 21,
    INVALID_CLIENT = 22,
    INVALID_PAYMENT = 23,
    UNAUTHORIZED = 24,
    RECEIPT_REFRESH_FAILED = 25
};
typedef int CDVWizPurchaseError;

@interface WizPurchase : CDVPlugin <SKProductsRequestDelegate, SKPaymentTransactionObserver> {
    NSArray *validProducts;
    NSMutableArray *restoredTransactions;
    NSMutableDictionary *pendingTransactions;

    NSString *getProductDetailsCb;
    NSString *makePurchaseCb;
    NSString *makePurchaseProductId;
    NSMutableArray *restorePurchaseCallbacks;
    NSMutableDictionary *refreshReceiptCallbacks;
}

- (void)makePurchase:(CDVInvokedUrlCommand *)command;
- (void)getProductDetails:(CDVInvokedUrlCommand *)command;
- (void)finishPurchase:(CDVInvokedUrlCommand *)command;
- (void)getPendingPurchases:(CDVInvokedUrlCommand *)command;
- (void)restoreAllPurchases:(CDVInvokedUrlCommand *)command;
- (void)refreshReceipt:(CDVInvokedUrlCommand *)command;

@end
