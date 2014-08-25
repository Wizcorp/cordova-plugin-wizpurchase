package jp.wizcorp.phonegap.plugin.wizPurchase;

//Android Includes
import android.content.Intent;
import android.util.Log;

//Cordova Includes
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

//JSON Includes
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

//Java Utility Includes
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

//Java Smart Mobile Includes
import com.smartmobilesoftware.util.Purchase;
import com.smartmobilesoftware.util.IabHelper;
import com.smartmobilesoftware.util.IabResult;
import com.smartmobilesoftware.util.Inventory;
import com.smartmobilesoftware.util.SkuDetails;

/**
 * WizPurchasePlugin Plug-in
 *
 * @author		Ally Ogilvie
 * @copyright		Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file		WizPurchase.java
 * @about		In-App-Billing Cordova Plug-in.
 */
public class WizPurchasePlugin extends CordovaPlugin {

	public static final String TAG = "WizPurchase";
	private String mBase64EncodedPublicKey;
	private List<String> mRequestDetailSkus;

	// (arbitrary) request code for the purchase flow
	static final int RC_REQUEST = 10001;

	// DeveloperPayload instance
	private String mDevPayload;

	// The helper object
	IabHelper mHelper;

	// Inventory instance (Includes Inventory details and purchased items)
	Inventory mInventory;

	// Callback Definitions
	CallbackContext mRestoreAllCbContext;
	CallbackContext mProductDetailCbContext;
	CallbackContext mMakePurchaseCbContext;
	CallbackContext mGetPendingCbContext;
	CallbackContext mConsumeCbContext;

	// =================================================================================================
	//	Override Plugin Methods
	// =================================================================================================

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		Log.d(TAG, "initialising plugin");

		/* base64EncodedPublicKey should be YOUR APPLICATION'S PUBLIC KEY
		 * (that you got from the Google Play developer console). This is not your
		 * developer public key, it's the *app-specific* public key.
		 *
		 * Instead of just storing the entire literal string here embedded in the
		 * program,  construct the key at runtime from pieces or
		 * use bit manipulation (for example, XOR with some other string) to hide
		 * the actual key.  The key itself is not secret information, but we don't
		 * want to make it easy for an attacker to replace the public key with one
		 * of their own and then fake messages from the server.
		 */

		// Assign base64 encoded public key
		int billingKey = cordova.getActivity().getResources().getIdentifier("billing_key", "string", cordova.getActivity().getPackageName());
		mBase64EncodedPublicKey = cordova.getActivity().getString(billingKey);

		super.initialize(cordova, webView);
	}

	@Override
	public void onActivityResult(int requestCode, int resultCode, Intent data) {
		Log.d(TAG, "onActivityResult(" + requestCode + "," + resultCode + "," + data);

		// Pass on the activity result to the helper for handling
		if (!mHelper.handleActivityResult(requestCode, resultCode, data)) {
			// not handled, so handle it ourselves (here's where you'd
			// perform any handling of activity results not related to in-app
			// billing...
			super.onActivityResult(requestCode, resultCode, data);
		} else {
			Log.d(TAG, "onActivityResult handled by IABUtil.");
		}
	}

	// We're being destroyed. It's important to dispose of the helper here!
	@Override
	public void onDestroy() {
		super.onDestroy();

		// Very important:
		if (mHelper != null) {
			Log.d(TAG, "Destroying helper.");
			mHelper.dispose();
			mHelper = null;
		}
	}

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		Log.d(TAG, "Plugin execute called with action: " + action);

		// Reset all handlers
		mRestoreAllCbContext	= null;
		mProductDetailCbContext	= null;
		mMakePurchaseCbContext	= null;
		mGetPendingCbContext	= null;
		mConsumeCbContext		= null;

		if (action.equalsIgnoreCase("getPending")) {
			mGetPendingCbContext = callbackContext;
			action = "restoreAll";
		}

		if (action.equalsIgnoreCase("restoreAll")) {
			restoreAll(callbackContext);
			return true;
		} else if (action.equalsIgnoreCase("getProductDetail")) {
			getProductsDetails(args, callbackContext);
			return true;
		} else if (action.equalsIgnoreCase("makePurchase")) {
			makePurchase(args, callbackContext);
			return true;
		} else if (action.equalsIgnoreCase("consumePurchase")) {
			consumePurchase(args, callbackContext);
			return true;
		}
		return false;
	}

	// =================================================================================================
	//	Actions Methods
	// =================================================================================================

	/**
	 * Restore all Inventory products and purchases
	 *
	 * @param callbackContext Instance
	 **/
	private void restoreAll(CallbackContext callbackContext) throws JSONException {
		// Check if the Inventory is available
		if (mInventory != null) {
			// Get and return any previously purchased Items
			JSONArray jsonSkuList = new JSONArray();
			jsonSkuList = getPurchases();
			// Return result
			callbackContext.success(jsonSkuList);
		} else {
			// Initialise the Plug-In
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					List<String> skus = new ArrayList<String>();
					init(skus);
				}
			});
			// Retain the callback and wait
			mRestoreAllCbContext = callbackContext;
			retainCallBack(mRestoreAllCbContext);
		}
	}

	/**
	 * Get All Products Details
	 *
	 * @param args List of Product id to be retrieved
	 * @param callbackContext Instance
	 **/
	private void getProductsDetails(JSONArray args, CallbackContext callbackContext) throws JSONException {
		// Retrieve all given Product Ids
		JSONArray jsonSkuList = new JSONArray(args.getString(0));
		mRequestDetailSkus = new ArrayList<String>();
		// Populate productId list
		for (int i = 0; i < jsonSkuList.length(); i++) {
			mRequestDetailSkus.add(jsonSkuList.get(i).toString());
		}
		// Retain the callback and wait
		mProductDetailCbContext = callbackContext;
		retainCallBack(mProductDetailCbContext);

		// Check if the Inventory is available
		if (mInventory != null) {
			// Get all the Sku details for the List
			getSkuDetails(mRequestDetailSkus);
		} else {
			// Initialise the Plug-In with the given list
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					init(mRequestDetailSkus);
				}
			});
		}
	}

	/**
	 * Make the Product Purchase
	 *
	 * @param args Product Id to be purchased and DeveloperPayload
	 * @param callbackContext Instance
	 **/
	private void makePurchase(JSONArray args, CallbackContext callbackContext) throws JSONException {
		// Retain the callback and wait
		mMakePurchaseCbContext = callbackContext;
		retainCallBack(mMakePurchaseCbContext);
		// Instance the given product Id to be purchase
		final String productId = args.getString(0);
		// Update the DeveloperPayload with the given value. empty if not passed
		mDevPayload = args.optString(1);

		// Check if the Inventory is available
		if (mInventory != null) {
			// Set up the activity result callback to this class
			cordova.setActivityResultCallback(this);
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					// Buy the product
					buy(productId);
				}
			});
		} else {
			// Initialise the Plug-In adding the product to be purchased
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					List<String> skus = new ArrayList<String>();
					skus.add(0, productId);
					init(skus);
				}
			});
		}
	}

	/**
	 * Consume the Purchase
	 *
	 * @param args Product Id to be purchased and DeveloperPayload
	 * @param callbackContext Instance
	 **/
	private void consumePurchase(JSONArray args, CallbackContext callbackContext) throws JSONException {
		// Retain the callback and wait
		mConsumeCbContext = callbackContext;
		retainCallBack(mConsumeCbContext);

		// Check if the Inventory is available
		if (mInventory != null) {
			// Consume product
			consumePurchase(args);
		} else {
			// Initialise the Plug-In
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					List<String> skus = new ArrayList<String>();
					init(skus);
				}
			});
		}
	}

	// =================================================================================================
	//	Operation Methods
	// =================================================================================================

	/**
	 * Initialise the Plug-in
	 *
	 * @param skus List of Skus
	 **/
	private void init(final List<String> skus){
		Log.d(TAG, "init start ");
		// Some sanity checks to see if the developer (that's you!) really followed the
		// instructions to run this plugin
		if (mBase64EncodedPublicKey == null || mBase64EncodedPublicKey.isEmpty()) {
			throw new RuntimeException("Please put your app's public key in res/values/billing_key.xml.");
		}

		// Create the helper, passing it our context and the public key to verify signatures with
		Log.d(TAG, "Creating IAB helper.");
		mHelper = new IabHelper(cordova.getActivity(), mBase64EncodedPublicKey);

		// enable debug logging (for a production application, you should set this to false).

		// Start setup. This is asynchronous and the specified listener
		// will be called once setup completes.
		Log.d(TAG, "Starting setup.");

		mHelper.startSetup(new IabHelper.OnIabSetupFinishedListener() {
			public void onIabSetupFinished(IabResult result) {
				Log.d(TAG, "Setup finished.");
				if (!result.isSuccess()) {
					// Oh no, there was a problem.
					// callbackContext.error("Problem setting up in-app billing: " + result);
					Log.d(TAG, "Error : " + result);
					String errorMsg = "unknownError";
					if (result.getResponse() == 3) {
						// Billing is not available
						// Missing Google Account
						errorMsg = "cannotPurchase";
					}

					// Set the error for the current context
					if (mRestoreAllCbContext != null) 			mRestoreAllCbContext.error(errorMsg);
					else if (mProductDetailCbContext != null)	mProductDetailCbContext.error(errorMsg);
					else if (mGetPendingCbContext != null)		mGetPendingCbContext.error(errorMsg);
					else if (mMakePurchaseCbContext != null)	mMakePurchaseCbContext.error(errorMsg);
					else if (mConsumeCbContext != null)			mConsumeCbContext.error(errorMsg);

					// Stop further processing
					return;
				}

				// In the case that the initialisation was made during the makePurchase action
				// We will have a product to purchase
				if (mMakePurchaseCbContext != null) {
					// This is a purchase request
					buy(skus.get(0));
					return;
				}

				// Hooray, IAB is fully set up. Now, let's get an inventory of stuff we own.
				if (skus.size() <= 0){
					Log.d(TAG, "Setup successful. Querying inventory.");
					mHelper.queryInventoryAsync(mGotInventoryListener);
				} else {
					Log.d(TAG, "Setup successful. Querying inventory w/ SKUs. " + skus.toString());
					mHelper.queryInventoryAsync(true, skus, mGotDetailsListener);
				}
			}
		});
	}

	/**
	 * Buy the Product
	 *
	 * @param sku Product Sku to be purchase
	 **/
	private void buy(final String sku) {
		// Process the purchase for the given product id and developerPayload
		mHelper.launchPurchaseFlow(
				cordova.getActivity(),
				sku,
				RC_REQUEST,
				mPurchaseFinishedListener,
				mDevPayload);
	}

	/**
	 * Consume a purchase
	 *
	 * @param data Sku or Array of skus of products to be consumed
	 **/
	private void consumePurchase(JSONArray data) throws JSONException{
		// Returning Error Message
		String errorMsg = "";

		// Iterate the given Array of skus
		for (int i = 0; i < data.length(); i++) {
			// Instance the current sku to be consumed
			String sku = data.getString(i);
			// Skip invalid skus
			if (sku == null) continue;
			if (sku == "") continue;
			Log.d(TAG, "fetching item: " + sku);
			// Get the purchase from the inventory
			Purchase purchase = mInventory.getPurchase(sku);
			// Check if we actually have a purchase to consume
			if (purchase != null) {
				Log.d(TAG, "purchase is: " + purchase.toString());
				// Process the consumption asynchronously
				mHelper.consumeAsync(purchase, mConsumeFinishedListener);
			} else {
				// Check if we already have an error and add the separator for handle a split later on
				// TODO: Can the sku contain "."? if so a different separator would be needed
				if (!errorMsg.isEmpty()) errorMsg += ".";
				// Add the current sku to the returning error string
				errorMsg += "Sku: " + sku + " was not consumable";
			}
		}
		// Check if we need to process an Error Listener
		if (mConsumeCbContext != null) {
			// If we have errors send the error to the listener
			if (!errorMsg.isEmpty()) mConsumeCbContext.error(errorMsg);
			// Clean the listener instance
			mConsumeCbContext = null;
		}
	}

	/**
	 * Get the list of purchases
	 *
	 **/
	private JSONArray getPurchases() throws JSONException {
		// Get the list of owned items
		List<Purchase>purchaseList = mInventory.getAllPurchases();

		// Convert the java list to JSON
		JSONArray jsonPurchaseList = new JSONArray();
		// Iterate all products
		for (Purchase p : purchaseList) {
			jsonPurchaseList.put(new JSONObject(p.getOriginalJson()));
		}
		// Return the JSON list
		return jsonPurchaseList;
	}

	/**
	 * Get the SkuDetails
	 *
	 * @param skus List of product skus to be processed
	 **/
	private void getSkuDetails(final List<String> skus){
		Log.d(TAG, "Querying inventory w/ SKUs.");
		mHelper.queryInventoryAsync(true, skus, mGotDetailsListener);
	}

	// =================================================================================================
	//	Listeners Methods
	// =================================================================================================

	/**
	 * Got Inventory Listener
	 * Listener that's called when we finish querying the items and subscriptions we own
	 **/
	IabHelper.QueryInventoryFinishedListener mGotInventoryListener = new IabHelper.QueryInventoryFinishedListener() {
		public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
			Log.d(TAG, "Inside mGotInventoryListener");
			// Check if there is error and update the Inventory
			if (!hasErrorsAndUpdateInventory(result, inventory)) {}
			Log.d(TAG, "Query inventory was successful.");

			// Check if we have the handler
			if (mRestoreAllCbContext != null) {
				// This array holds Google data
				JSONArray jsonSkuList;

				// Create our new array for JavaScript
				JSONArray skuList = new JSONArray();
				try {
					// Populate with Google data
					jsonSkuList = getPurchases();

					// Rebuild Object for JavaScript
					for (int i = 0; i < jsonSkuList.length(); i++) {
						JSONObject skuObject = new JSONObject();
						skuObject = jsonSkuList.getJSONObject(i);

						// Create return Object
						JSONObject pendingObject = new JSONObject();
						pendingObject.putOpt("platform", "android");
						pendingObject.putOpt("orderId", skuObject.getString("orderId"));
						pendingObject.putOpt("packageName", skuObject.getString("packageName"));
						pendingObject.putOpt("productId", skuObject.getString("productId"));
						pendingObject.putOpt("purchaseTime", skuObject.getString("purchaseTime"));
						pendingObject.putOpt("purchaseState", skuObject.getString("purchaseState"));
						pendingObject.putOpt("developerPayload", skuObject.getString("developerPayload"));
						pendingObject.putOpt("receipt", skuObject.getString("purchaseToken"));

						// Add new object into array
						skuList.put(pendingObject);
					}
				} catch (JSONException e) { }

				// Return result
				mRestoreAllCbContext.success(skuList);
				// Clear the handler instance
				mRestoreAllCbContext = null;
			}
		}
	};

	/**
	 * Got SkuDetails Listener
	 * Listener that's called when we finish querying the details of the products
	 **/
	IabHelper.QueryInventoryFinishedListener mGotDetailsListener = new IabHelper.QueryInventoryFinishedListener() {
		public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
			Log.d(TAG, "Inside mGotDetailsListener");
			// Check if there is error and update the Inventory
			if (hasErrorsAndUpdateInventory(result, inventory)) {
				return;
			}
			Log.d(TAG, "Query details was successful." + result.toString());

			// Check if we have the handler
			if (mProductDetailCbContext != null) {
				// We will gather here any wrong sku and log it out later.
				String wrongSku = "";
				// Line separator instance
				String newline = System.getProperty("line.separator");

				// Get the returned list of SkuDetails from Google API.
				// This is the Full Developer Inventory, regardless the incorrect skus in our query
				List<SkuDetails>skuList = inventory.getAllProducts();

				// Build the return Object
				JSONObject skusObject = new JSONObject();

				Log.d(TAG, "skuList: " + skuList);
				if (skuList != null && !skuList.isEmpty()) {
					// Iterate over the requestDetailSkus and check we have info for each
					Iterator<String> requestSkuIter = mRequestDetailSkus.iterator();

					// Iterate all skus
					while (requestSkuIter.hasNext()) {
						for (SkuDetails sku : skuList) {
							if (!sku.getSku().equalsIgnoreCase(requestSkuIter.next()) ) {
								// If we already have invalid skus add a new line
								if (!wrongSku.isEmpty())wrongSku += newline;
								// Add the incorrect sku to our list
								wrongSku += "sku not found in Google Inventory: " + sku;
							} else {
								// Build the sku details object
								JSONObject skuObject = new JSONObject();
								try {
									// Fill the sku details
									skuObject.put("productId", sku.getSku());
									skuObject.put("price", sku.getPrice());
									skuObject.put("description", sku.getDescription());
									skuObject.put("name", sku.getTitle());
									skuObject.put("json", sku.toJson());
									// Add the current sku details to the returning object
									skusObject.put(sku.getSku(), skuObject);
								} catch (JSONException e) { }
							}
						}
					}
					// If we have wrong sku log it out for the developer, this should be enough otherwise a return object should be issue
					if (!wrongSku.isEmpty()){
						Log.d(TAG, "One or more Sku were not found in Google Inventory");
						Log.d(TAG, wrongSku);
					}
				}

				// At this point return the success for all we got (even an empty Inventory)
				// All what we found in here is all the sku who actually does exist in the developer inventory
				// If something is missing the developer will refine his query
				mProductDetailCbContext.success(skusObject);
				mProductDetailCbContext = null;
			}
		}
	};

	/**
	 * Purchase Finished Listener
	 * Callback for when a purchase is finished
	 **/
	IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener() {
		public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
			Log.d(TAG, "Purchase finished: " + result + ", purchase: " + purchase);

			// Check if we have the handler
			if (mMakePurchaseCbContext != null) {
				// Check if there are purchase errors
				if (result.isFailure()) {
					// Get the Error message
					String errMsg = returnErrorString(result.getResponse());
					// Dispatch the Error event
					mMakePurchaseCbContext.error(errMsg);
					// Clear the handler and stop processing
					mMakePurchaseCbContext = null;
					return;
				}

				Log.d(TAG, "Purchase successful.");

				// Build the return Object
				JSONObject purchaseResult = new JSONObject();
				try {
					purchaseResult.put("platform", "android");
					purchaseResult.put("orderId", purchase.getOrderId());
					purchaseResult.put("developerPayload", purchase.getDeveloperPayload());
					purchaseResult.put("receipt", purchase.getToken());
					purchaseResult.put("productId", purchase.getSku());
					purchaseResult.put("packageName", cordova.getActivity().getPackageName());
					// Return the object
					mMakePurchaseCbContext.success(purchaseResult);
				} catch (JSONException e) { }
				// Clear the handler
				mMakePurchaseCbContext = null;
			}

			// Add the purchase to the inventory
			mInventory.addPurchase(purchase);
		}
	};

	/**
	 * Consume Finished Listener
	 * Called when consumption is complete
	 **/
	IabHelper.OnConsumeFinishedListener mConsumeFinishedListener = new IabHelper.OnConsumeFinishedListener() {
		public void onConsumeFinished(Purchase purchase, IabResult result) {
			Log.d(TAG, "Consumption finished. Purchase: " + purchase + ", result: " + result);

			// Check if we have a successful consumption
			if (result.isSuccess()) {
				// After consumption remove the item from the inventory
				mInventory.erasePurchase(purchase.getSku());
				Log.d(TAG, "Consumption successful. .");

				// Check if we have the handler
				if (mConsumeCbContext != null) {
					// Dispatch the Success event
					mConsumeCbContext.success();
				}
			} else {
				// Check if we have the handler
				if (mConsumeCbContext != null) {
					// Get the Error message
					String errorMsg = returnErrorString(result.getResponse());
					// Dispatch the Error event
					mConsumeCbContext.error(errorMsg);
				}
			}
			// Clear the handler
			mConsumeCbContext = null;
		}
	};

	// =================================================================================================
	//	Utility Methods
	// =================================================================================================

	/**
	 * Check if there is any errors in the iabResult and update the inventory
	 *
	 * @param result IabResult instance
	 * @param inventory Inventory instance
	 *
	 * @return Result of the check
	 **/
	private Boolean hasErrorsAndUpdateInventory(IabResult result, Inventory inventory) {
		Log.d(TAG, "Update Inventory");
		// Check if the result failed
		if (result.isFailure()) {
			// Check if we have the handler
			Log.e(TAG, "Error: " + result.toString());
			if (mProductDetailCbContext != null) {
				// Dispatch the Error event
				mProductDetailCbContext.error(returnErrorString(result.getResponse()));
				// Clear the handler
				mProductDetailCbContext = null;
			}

			if (mRestoreAllCbContext != null) {
				// Dispatch the Error event
				mRestoreAllCbContext.error(returnErrorString(result.getResponse()));
				// Clear the handler
				mRestoreAllCbContext = null;
			}
			// Return true since we found an error
			return true;
		}
		// Update the inventory and return false (no error on result)
		mInventory = inventory;
		return false;
	}

	/**
	 * Retain a Callback
	 *
	 * @param target CallBack Instance to retain
	 * @param source Source Callback instance
	 **/
	private void retainCallBack(CallbackContext cb) {
		// Retain callback and wait
		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
		result.setKeepCallback(true);
		cb.sendPluginResult(result);
	}

	/**
	 * Error converter helper
	 * Map the given error index into a human readable error string
	 *
	 * @param error Error code to be converted
	 **/
	private String returnErrorString(int error) {

		// Define the default message
		String errMsg = "unknownError";
		// Update the message according to the given code
		if (error == -1001) 		errMsg = "remoteException";
		else if (error == -1002)	errMsg = "badResponse";
		else if (error == -1003)	errMsg = "badSignature";
		else if (error == -1004)	errMsg = "sendIntentFailed";
		else if (error == -1005)	errMsg = "userCancelled";
		else if (error == -1006)	errMsg = "invalidPurchase";
		else if (error == -1007)	errMsg = "missingToken";
		else if (error == -1008)	errMsg = "unknownError";
		else if (error == -1009)	errMsg = "noSubscriptions";
		else if (error == -1010)	errMsg = "invalidConsumption";
		else if (error == 1)		errMsg = "userCancelled";
		else if (error == 2)		errMsg = "unknownError";
		else if (error == 3)		errMsg = "cannotPurchase";
		else if (error == 4)		errMsg = "unknownProductId";
		else if (error == 5)		errMsg = "unknownError";
		else if (error == 6)		errMsg = "invalidPurchase";
		else if (error == 7)		errMsg = "alreadyOwned";
		else if (error == 8)		errMsg = "notOwned";

		// Return the Message
		return errMsg;
	}

	/** Verifies the developer payload of a purchase. */
	boolean verifyDeveloperPayload(Purchase p) {
		@SuppressWarnings("unused")
		String payload = p.getDeveloperPayload();

		/*
		 * TODO: verify that the developer payload of the purchase is correct. It will be
		 * the same one that you sent when initiating the purchase.
		 *
		 * WARNING: Locally generating a random string when starting a purchase and
		 * verifying it here might seem like a good approach, but this will fail in the
		 * case where the user purchases an item on one device and then uses your app on
		 * a different device, because on the other device you will not have access to the
		 * random string you originally generated.
		 *
		 * So a good developer payload has these characteristics:
		 * 
		 * 1. If two different users purchase an item, the payload is different between them,
		 *    so that one user's purchase can't be replayed to another user.
		 *
		 * 2. The payload must be such that you can verify it even when the application wasn't the
		 *    one who initiated the purchase flow (so that items purchased by the user on
		 *    one device work on other devices owned by the user).
		 *
		 * Using your own server to store and verify developer payloads across application
		 * installations is recommended.
		 */
		return true;
	}
}
