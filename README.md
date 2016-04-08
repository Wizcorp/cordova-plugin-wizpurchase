cordova-plugin-wizpurchase
===========================

A cross-platform mobile application payment API for iOS IAP and Android Billing.

- PhoneGap Version : 3.3


-----
## Major API changes warning
***API changed since v1.x.x. Please be sure you target the right version. There are no API changes except on new major versions.
If your plugin dependency points directly to Github, make sure to have the right version by adding it at the end of the URL, e.g.:***
https://github.com/Wizcorp/cordova-plugin-wizpurchase#v1.2.0

-----


**NOTE:**
- **Not currently supporting subscriptions.**
- **Receipts on iOS use API ```appStoreReceiptURL``` available from iOS 7**

***A lot of work from the Android side of this plugin must be credited to @[poiuytrez](https://github.com/poiuytrez)'s [AndroidInAppBilling](https://github.com/poiuytrez/AndroidInAppBilling/) plugin. We re-used some plugin class code and all the utility classes, but replaced a lot of the API to be usable in a cross-platform manner with iOS. Many thanks goes to him for his hard work.***

## Install

### via CLI

	cordova plugin add https://github.com/Wizcorp/cordova-plugin-wizpurchase --variable BILLING_KEY="YOUR_BILLING_KEY"

### via config.xml

	<plugin name="cordova-plugin-wizpurchase" spec="1.2.0">
	    <variable name="BILLING_KEY" value="YOUR_BILLING_KEY" />
	</plugin>
	
### via Phonegap Build (PGB)

	<plugin name="cordova-plugin-wizpurchase" spec="1.2.0">
			<param name="BILLING_KEY" value="YOUR_BILLING_KEY" />
	</plugin>


You need to specify your billing key **only** if you need Android support.

## Setup

#### iOS

- In iTunes Connect create: your application, any items and an IAP test user (on the main screen see "Manage Users").

- Test on a real device (not simulator).

- Log out of any existing Apple iTunes accounts on the device before testing.

- Make sure your application has a version number (do not leave it blank).

#### Android

- Set `debuggable` to `false` and upload a signed version of you application to the Google Play Developer Console.

- Add items to the Google Play Developer Console.

- Upload your apk to Alpha or Beta environment.

- Add your list of test users (Google Group), in the same screen you should see a link ** *1 **

- ** *1 download the application from the link above [important!] **

- Be sure you are logged in to a Google Developer Account on your device.

- Be sure to use a real device (not emulator).


## Purchase Flow

![image](purchase_flow.png)

## Purchase object

Purchase objects contain product information that can be used for verification.

```
{
	platform: "ios" or "android",
	orderId: transaction identifier for iOS or order ID for Android,
	receipt: purchaseToken or ios receipt as String,
	productId: "sword001",
	packageName: "jp.wizcorp.game",
	purchaseTime: Android-specific, time the product was purchased in ms since the epoch (Jan 1, 1970),
	purchaseState: Android-specific, "0" (purchased), "1" (canceled) or "2" (refunded),
	json: Android-specific, original JSON purchase data,
	developerPayload: Android-specific, string specified by the developer in the purchase request,
	signature: Android-specific, signature of the purchase data signed with the private key of the developer
}
```

## JavaScript APIs

### getPendingPurchases(Function success, Function failure)

Get a list of purchases which have not been ended yet using ```finishPurchase```.

- *Return* success with an Array of zero or more ```Purchase``` objects.
- *Return* failure with error

Developers should check any returned items with server APIs and complete their purchase using ```finishPurchase```.

### restoreAllPurchases(Function success, Function failure)

Get a list of previous purchases of non-consumable and not yet finished purchases.

- *Return* success with an Array of zero or more ```Purchase``` objects.
- *Return* failure with error

Developers should check any returned items with server APIs. If any items that exist are consumables but have not been consumed, the developer should consume them using ```finishPurchase``` because it is likely that a previous purchase was not completed.

### makePurchase(String productId, Function success, Function failure)

Make a purchase given a product ID (Quantity is not settable with the API, it is always 1 to be cross-platform complete).

(ANDROID: A NON-CONSUMABLE CANNOT BE PURCHASED IF IT IS ALREADY OWNED [not-consumed], this applies to any product ID that has not been consumed with ```finishPurchase```).

** See security notes below **

- *Return* success with a ```Purchase``` Object
- *Return* failure with error

On success do a receipt verification (if server API exists) gift the user.

|  Android Verification API |
| --------- |:--------:| ------:|
|  URIs relative to *https://www.googleapis.com/androidpublisher/v1.1/applications*, unless otherwise note |
| **GET**  |
| / **[packageName]**/inapp/**[productId]**/purchases/**[token]** |
| Checks the purchase and consumption status of an inapp item. |


|  iOS Verification API |
| --------- |:--------:| ------:|
|  Base64 encode the receipt and create a JSON object as follows: `{ "receipt-data" : "receipt bytes here" }`  
| **POST**  |
| https://buy.itunes.apple.com/verifyReceipt |
| JSON is returned. If the value of the `status` key is 0, this is a valid receipt. |

NOTE: Always verify your receipt for auto-renewable subscriptions first with the production URL; proceed to verify with the sandbox URL if you receive a 21007 status code. Following this approach ensures that you do not have to switch between URLs while your application is being tested or reviewed in the sandbox or is live in the App Store.

### finishPurchase(String productId, Boolean isConsumable, Function success, Function failure)

Finish transaction of a purchase for given productId. Its associated product will be consumed if ```isConsumable``` is set to ```true```.

- *Return* success
- *Return* failure with error

### getProductDetails(String productId or Array of productIds, Function success, Function failure)

Get the details for a single productId or for an Array of productIds.

- *Return* success with Object containing country, currency code and key/value map of products
- *Return* failure with error

NB: Currently on Android the country code can not be guessed and as such, it is not returned.

```json
{
	"country": "GB",
	"currency": "GBP",
	"products": {
		"sword001": {
			"productId": "sword001",
			"name": "Sword of Truths",
			"description": "Very pointy sword. Sword knows if you are lying, so don't lie.",
			"price": "Formatted price of the item, including its currency sign.",
			"priceMicros": "Price in micro-units as an unformatted string, where 1,000,000 micro-units equal one unit of the currency."
		},
		"shield001": {
			"productId": "shield001",
			"name": "Shield of Peanuts",
			"description": "A shield made entirely of peanuts.",
			"price": "Formatted price of the item, including its currency sign.",
			"priceMicros": "Price in micro-units as an unformatted string, where 1,000,000 micro-units equal one unit of the currency."
		}
	}
}
```

or empty `{ }` if productIds was an empty array.

- *Return* failure with error as the only argument

#### Security notes (Android)

*** You (the developer) should verify that the orderId is a unique value that you have not previously processed, and the developerPayload string matches the token that you sent previously with the purchase request. As a further security precaution, you should perform the verification on your own secure server. ***

### Error Handling

Failure callbacks return an error as an integer. See the following error table:

| Code | Constant                    | Description                                                                                            |
|-----:|:----------------------------|:-------------------------------------------------------------------------------------------------------|
|    1 | `UNKNOWN_ERROR`             |                                                                                                        |
|    2 | `ARGS_TYPE_MISMATCH`        |                                                                                                        |
|    3 | `ARGS_ARITY_MISMATCH`       |                                                                                                        |
|    4 | `IOS_VERSION_ERR`           |                                                                                                        |
|    5 | `INVALID_RECEIPT`           |                                                                                                        |
|    6 | `INVALID_TRANSACTION_STATE` |                                                                                                        |
|    7 | `PURCHASE_NOT_FOUND`        |                                                                                                        |
|    8 | `PURCHASE_NOT_PENDING`      |                                                                                                        |
|    9 | `REMOTE_EXCEPTION`          |                                                                                                        |
|   10 | `BAD_RESPONSE`              |                                                                                                        |
|   11 | `BAD_SIGNATURE`             |                                                                                                        |
|   12 | `SEND_INTENT_FAILED`        |                                                                                                        |
|   13 | `USER_CANCELLED`            | Indicates that the user cancelled a payment request                                                    |
|   14 | `INVALID_PURCHASE`          |                                                                                                        |
|   15 | `MISSING_TOKEN`             |                                                                                                        |
|   16 | `NO_SUBSCRIPTIONS`          |                                                                                                        |
|   17 | `INVALID_CONSUMPTION`       |                                                                                                        |
|   18 | `CANNOT_PURCHASE`           | Purchasing is not possible for the following reasons:<br />- purchase is being made on a simulator or emulator,<br />- the device has been identified as rooted |
|   19 | `UNKNOWN_PRODUCT_ID`        | Indicates that the requested product is not available or could not be found in the store               |
|   20 | `ALREADY_OWNED`             | [Android only] This item has already been bought. It cannot be bought again without consuming it first |
|   21 | `NOT_OWNED`                 |                                                                                                        |
|   22 | `INVALID_CLIENT`            | Indicates that the client is not allowed to perform the attempted action                               |
|   23 | `INVALID_PAYMENT`           | Indicates that one of the payment parameters was not recognized                                        |
|   24 | `UNAUTHORIZED`              | Indicates that the user is not allowed to authorise payments (e.g. parental lock)                      |
|   24 | `RECEIPT_REFRESH_FAILED`    |                                                                                                        |

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
