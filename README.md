phonegap-plugin-wizPurchase
===========================

A cross-platform mobile application payment API for iOS IAP and Android Billing. 

# [API is Draft]

** NOTE: Not currently supporting subscriptions **


## Private (Native APIs)

### init( )

Intialisation method. Sets up any transaction requirements or delegates, toggles logging in debug mode
					
iOS should create `PGSKPaymentTransactionObserver` on `self` and `retain`.
Then add that observer to the previously created transaction observer:
`[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];`
Finally setup SQLite DB for storing transaction receipts (mark for cloud backup in docs dir?)


	
Android should init a Google IAP helper class (Provides convenience methods for in-app billing.)
with an encoded public key (This is used for verification of purchase signatures. 
You can find your app's base64-encoded public key in your application's page on 
Google Play Developer Console.).

### canPurchase( )

Check to see if the client has puchasing enabled.

Can detect if rooted iOS device or emulator / simulator etc.
						
iOS calls: `[SKPaymentQueue canMakePayments]`
	
- *Return* (Boolean) value to specify whether the client can make a purchase 
	
## Public (JavaScript APIs)

** NOTE: All APIs run canMakePurchase() natively (instead of in JS code to prevent any JS hacks) **


### getPurchases(Function success, Function failure)

Get a list of non-consumable AND consumable (that have not been consumed) item receipts / tokens 
								
iOS should internally... 
Check the local database on unconsumed transaction Ids etc.
				
`[[SKPaymentQueue defaultQueue] addTransactionObserver:self];`
`[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];`		
then `(void)paymentQueueRestoreCompletedTransactionsFinished`

Android should internally call `Bundle getPurchases()` on IInAppBillingService.aidl Class
This populates an Inventory object with all purchases ever made except the consumed purchases.
					
- *Return* success with Array of puchaseTokens (Android) or receipts (iOS)
	* e.g. Android
		`[ "puchase-token-string", ... ] }` 
		
- *Return* failure with error 

(Developer should check any returned items with server APIs. If any items exist that are consumables, but have not been comsumed. The developer should call `consumePurchase()` because it is likely a previous purchase was not completed )
					

### makePurchase(String productId, Function success, Function failure)

Make a purchase given a product Id (Quantity is not settable with the API, it is always 1 to be cross platform complete).
					
(ANDROID: A NON-CONSUMABLE CANNOT BE PURCHASED IF IT IS ALREADY OWNED [not-consumed], this applies to any product Id that has not been comsumed with `consumePurchse()`).
					
iOS should internally call `[SKMutablePayment paymentWithProductIdentifier:productId];`
then add the payment to the payment queue `[[SKPaymentQueue defaultQueue] addPayment:payment]`
When a transaction is complete the receipt is stored in the DB.
					
Android internally should call void `launchPurchaseFlow()` on IInAppBillingService.aidl Class
Upon a successful purchase, the user’s purchase data is cached locally by Google Play’s In-app Billing service.

** See security notes below **

- *Return* success with transaction information

		{
			platform: "ios" or "android",
			receipt: purchaseToken or ios receipt as String,
			productId: "sword001",
			packageName: "jp.wizcorp.game"
		}
	
- *Return* failure with error

On success do a receipt verification (if server API exists) gift the user.

|  Android Verification API |
| --------- |:--------:| ------:|
|  URIs relative to *https://www.googleapis.com/androidpublisher/v1.1/applications*, unless otherwise note |
| **GET**  | /**[packageName]**/inapp/**[productId]**/purchases/**[token]** | Checks the purchase and consumption status of an inapp item. |
	

|  iOS Verification API |
| --------- |:--------:| ------:|
|  Base64 encode the receipt and create a JSON object as follows: `{ "receipt-data" : "receipt bytes here" }`  |
| **POST**  | https://buy.itunes.apple.com/verifyReceipt | JSON is returned. If the value of the `status` key is 0, this is a valid receipt. |

NOTE: Always verify your receipt for auto-renewable subscriptions first with the production URL; proceed to verify with the sandbox URL if you receive a 21007 status code. Following this approach ensures that you do not have to switch between URLs while your application is being tested or reviewed in the sandbox or is live in the App Store.
			
### consumePurchase(String transactionId / purchaseId, Function success, Function failure)

Consume the purchase given an ID (Android purchaseToken | iOS transactionId).
										
iOS removes the item from DB.
					
Android internally calls `int consumePurchase()` on IInAppBillingService.aidl Class
		
Upon a successful purchase, the user’s purchase data is cached locally by Google Play’s In-app Billing service.

** See security notes below **

- *Return* success
- *Return* failure with error 
					

### getProductDetails(Array products)

Get the details for an array of products.
					
iOS should internally call `[[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers]`

Android should internally call `queryInventoryAsync()` on the helper class which should call `getSkuDetails()`.
					
- *Return* success with Array of product objects

```json
{
	"sword001": {
		"productId": "sword001",
		"name": "Sword of Truths",
		"description": "Very pointy sword. Sword knows if you are lying, so don't lie.",
		"price": 10.15
	},
	"shield001": {
		"productId": "shield001",
		"name": "Shield of Peanuts",
		"description": "A shield made entirely of peanuts.",
		"price": 5.5
	}
}
```

or empty `{ }` if productIds was an empty array.

- *Return* failure with error as the only argument
	

#### Security notes (Android)

*** You (the developer) should verify that the orderId is a unique value that you have not previously processed, and the developerPayload string matches the token that you sent previously with the purchase request. As a further security precaution, you should perform the verification on your own secure server. ***
	
======
Ref Links
======

### iOS

[http://docs.xamarin.com/guides/ios/application_fundamentals/in-app_purchasing/part_4_-_purchasing_non-consumable_products/](http://docs.xamarin.com/guides/ios/application_fundamentals/in-app_purchasing/part_4_-_purchasing_non-consumable_products/)

[https://github.com/Wizcorp/phonegap-plugin-inAppPurchaseManager/blob/v3.0/platforms/ios/HelloCordova/Plugins/InAppPurchaseManager/InAppPurchaseManager.m](https://github.com/Wizcorp/phonegap-plugin-inAppPurchaseManager/blob/v3.0/platforms/ios/HelloCordova/Plugins/InAppPurchaseManager/InAppPurchaseManager.m)

[http://stackoverflow.com/a/17734756/2206385](http://stackoverflow.com/a/17734756/2206385)

### Android

[http://developer.android.com/google/play/billing/api.html](http://developer.android.com/google/play/billing/api.html)

[http://developer.android.com/training/in-app-billing/purchase-iab-products.html](http://developer.android.com/training/in-app-billing/purchase-iab-products.html)

[https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/util/IabHelper.java](https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/util/IabHelper.java)

[https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/inappbilling/InAppBillingPlugin.java](https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/inappbilling/InAppBillingPlugin.java)

[https://developers.google.com/android-publisher/v1_1/](https://developers.google.com/android-publisher/v1_1/)
