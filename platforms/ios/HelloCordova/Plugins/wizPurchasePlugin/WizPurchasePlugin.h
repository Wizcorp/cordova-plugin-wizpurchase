/* wizPurchasePlugin
 *
 * @author Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file wizPurchasePlugin.h
 *
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <Cordova/CDVPlugin.h>

enum CDVWizPurchaseError {
    NO_ERROR = 0,
    IOS_VERSION_ERR = 1,
    INVALID_RECEIPT = 2
};
typedef int CDVWizPurchaseError;

@interface WizPurchasePlugin : CDVPlugin <SKProductsRequestDelegate, SKPaymentTransactionObserver> {
    SKProductsResponse *productsResponse;
    NSString *getProductDetailsCb;
    NSString *makePurchaseCb;
    NSString *restorePurchaseCb;
    NSMutableDictionary *refreshReceiptCallbacks;
}

- (void)canMakePurchase:(CDVInvokedUrlCommand *)command;
- (void)makePurchase:(CDVInvokedUrlCommand *)command;
- (void)getProductDetail:(CDVInvokedUrlCommand *)command;
- (void)consumePurchase:(CDVInvokedUrlCommand *)command;
- (void)getPending:(CDVInvokedUrlCommand *)command;
- (void)restoreAll:(CDVInvokedUrlCommand *)command;

@end
