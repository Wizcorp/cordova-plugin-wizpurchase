phonegap-plugin-wizPurchase
===========================

A cross-platform mobile application payment API for iOS IAP and Android Billing. 

# API Draft

wizPurchase API
==========

** NOTES: Not currently supporting subscriptions **


### private (Native APIs)

## init 		

- Intialisation method. Sets up any transaction requirements or delegates, toggles logging in debug mode
					
	iOS should create PGSKPaymentTransactionObserver on self and retain.
	Then add that observer to the previously created transaction observer:
	[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
	Finally setup SQLite DB for storing transaction receipts (mark for cloud backup in docs dir?)
	
	Android should init a Google IAP helper class (Provides convenience methods for in-app billing.)
	with an encoded public key (This is used for verification of purchase signatures. 
	You can find your app's base64-encoded public key in your application's page on 
	Google Play Developer Console.).

## canPurchase

 - Check to see if the client has puchasing enabled.

	Can detect if rooted iOS device or emulator / simulator etc.
						
	iOS calls: [SKPaymentQueue canMakePayments]

	
	*Return* (Boolean) value to specify whether the client can make a purchase 
	
### public (JS APIs)

** NOTE: All APIs run canMakePurchase() natively (instead of in JS code to prevent any JS hacks) **


## getPurchases

- Get a list of non-consumable AND consumable (that have not been consumed) item receipts / tokens 
								
	iOS should internally... 
	Check the local database on unconsumed transaction Ids etc.
				
	`[[SKPaymentQueue defaultQueue] addTransactionObserver:self];`
	`[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];`		
	then `(void)paymentQueueRestoreCompletedTransactionsFinished`

	Android should internally call `Bundle getPurchases()` on IInAppBillingService.aidl Class
	This populates an Inventory object with all purchases ever made except the consumed purchases.
					
	*Return* success with transactionIds / purchaseTokens / receipt (Array / Object)
	
	*Return* failure with error 

(if consumables exist in the DB, that have not been comsumed. The developer should call `consumePurchase()` )
					

## makePurchase

- Make a purchase given a product ID. (Quantity is always 1 to be cross platform complete).
					
	(A NON-CONSUMABLE CANNOT BE PURCHASED IF IT IS ALREADY OWNED [not-consumed], 
	for Android this applies to any product Id that has not been completed).
					
	iOS should internally call [SKMutablePayment paymentWithProductIdentifier:productId];
	then add the payment to the payment queue [[SKPaymentQueue defaultQueue] addPayment:payment]
	When a transaction is complete the receipt is stored in the DB.
					
	Android internally should call void launchPurchaseFlow() on IInAppBillingService.aidl Class
	Upon a successful purchase, the user’s purchase data is cached locally by Google Play’s In-app Billing service.
	* See security notes
					 
					
	*Return* success with transaction information (Object) // After receipt verification (if exists) gift user
	
	*Return* failure with error 
	
					
## consumePurchase

- Consume the purchase given an ID (Android purchaseToken | iOS transactionId).
										
	iOS removes the item from DB.
					
	Android internally calls int consumePurchase() on IInAppBillingService.aidl Class
		
	Upon a successful purchase, the user’s purchase data is cached locally by Google Play’s In-app Billing service.
	* See security notes
					
	*Return* success
	
	*Return* failure with error 
					

## getProductDetails

- Get the details for an array of products (minimum 1).
					
	iOS should internally call [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers]

	Android should internally call queryInventoryAsync() on the helper class.
					
	*Return* success with product objects (Object) in products object (Object)
	e.g. `{ <productId> : <product object>, <productId> : <product object>  }` or empty data for no productIds `{ }`
	
	*Return* failure with error 
					
	

#### Security notes (Android)

***You (the developer) should verify that the orderId is a unique value that you have not previously processed, and the developerPayload string matches the token that you sent previously with the purchase request. As a further security precaution, you should perform the verification on your own secure server.***
	
======
Ref Links
======

iOS
===

[http://docs.xamarin.com/guides/ios/application_fundamentals/in-app_purchasing/part_4_-_purchasing_non-consumable_products/](http://docs.xamarin.com/guides/ios/application_fundamentals/in-app_purchasing/part_4_-_purchasing_non-consumable_products/)

[https://github.com/Wizcorp/phonegap-plugin-inAppPurchaseManager/blob/v3.0/platforms/ios/HelloCordova/Plugins/InAppPurchaseManager/InAppPurchaseManager.m](https://github.com/Wizcorp/phonegap-plugin-inAppPurchaseManager/blob/v3.0/platforms/ios/HelloCordova/Plugins/InAppPurchaseManager/InAppPurchaseManager.m)


Android
======

[http://developer.android.com/google/play/billing/api.html](http://developer.android.com/google/play/billing/api.html)

[http://developer.android.com/training/in-app-billing/purchase-iab-products.html](http://developer.android.com/training/in-app-billing/purchase-iab-products.html)

[https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/util/IabHelper.java](https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/util/IabHelper.java)

[https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/inappbilling/InAppBillingPlugin.java](https://github.com/poiuytrez/AndroidInAppBilling/blob/master/v3/src/android/com/smartmobilesoftware/inappbilling/InAppBillingPlugin.java)