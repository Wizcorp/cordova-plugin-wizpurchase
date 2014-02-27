/*
 *
 * @author 	Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2014
 * @file	- WizPurchase.java
 * @about	- In-App-Billing Cordova plugin.
*/
package jp.wizcorp.phonegap.plugin.wizPurchase;

import android.content.Intent;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

import com.smartmobilesoftware.util.Purchase;
import com.smartmobilesoftware.util.IabHelper;
import com.smartmobilesoftware.util.IabResult;
import com.smartmobilesoftware.util.Inventory;
import com.smartmobilesoftware.util.SkuDetails;

public class wizPurchasePlugin extends CordovaPlugin {

    public static final String TAG = "WizPurchase";
    private String base64EncodedPublicKey;

    // (arbitrary) request code for the purchase flow
    static final int RC_REQUEST = 10001;
    
    // The helper object
    IabHelper mHelper;
    
    // A quite up to date inventory of available items and purchase items
    Inventory myInventory; 
    
    CallbackContext restoreAllCbContext;
    CallbackContext productDetailCbContext;
    CallbackContext makePurchaseCbContext;
    CallbackContext getPendingCbContext;
    CallbackContext consumeCbContext;
    
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    	Log.d(TAG, "initialising plugin");
    	// Assign base64 encoded public key
    	
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
    	int billingKey = cordova.getActivity().getResources().getIdentifier("billing_key", "string", cordova.getActivity().getPackageName());
    	base64EncodedPublicKey = cordova.getActivity().getString(billingKey);

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
    	
    	// very important:
    	Log.d(TAG, "Destroying helper.");
    	if (mHelper != null) {
    		mHelper.dispose();
    		mHelper = null;
    	}
    }
    
    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		Log.d(TAG, "Plugin execute called with action: " + action);


        restoreAllCbContext = null;
        productDetailCbContext = null;
        makePurchaseCbContext = null;
        getPendingCbContext = null;
        consumeCbContext = null;

		if (action.equalsIgnoreCase("getPending")) {
			getPendingCbContext = callbackContext;
			action = "restoreAll";
		}
		
		if (action.equalsIgnoreCase("restoreAll")) {
            // Get and return any previously purchased Items
	    	if (myInventory != null) {
	    		JSONArray jsonSkuList = new JSONArray();
	    		jsonSkuList = getPurchases();
	    		// Return result
	    		callbackContext.success(jsonSkuList);
	    	} else {
	    		// Initialize
	        	cordova.getThreadPool().execute(new Runnable() {
	                public void run() {
	                	List<String> sku = new ArrayList<String>();
	                	init(sku);
	                }
	            });

	    		// Retain callback and wait
	    		restoreAllCbContext = callbackContext;
	    		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
	    		result.setKeepCallback(true);
	    		restoreAllCbContext.sendPluginResult(result);
	    	}
            return true;
        } else if (action.equalsIgnoreCase("getProductDetail")) {
    		// Populate productId list
        	JSONArray jsonSkuList = new JSONArray(args.getString(0));
    		final List<String> sku = new ArrayList<String>();
    		for (int i = 0; i < jsonSkuList.length(); i++) {
    			sku.add(jsonSkuList.get(i).toString());
			}
    		// Retain callback and wait
    		productDetailCbContext = callbackContext;
    		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
    		result.setKeepCallback(true);
    		productDetailCbContext.sendPluginResult(result);
    		
        	if (myInventory != null) {
            	getProductDetails(sku);
	    	} else {
	    		// Initialize
	        	cordova.getThreadPool().execute(new Runnable() {
	                public void run() {
	                	init(sku);
	                }
	            });
	    	}
            return true;
    	} else if (action.equalsIgnoreCase("makePurchase")) {
    		// Retain callback and wait
    		makePurchaseCbContext = callbackContext;
    		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
    		result.setKeepCallback(true);
    		makePurchaseCbContext.sendPluginResult(result);
    		
	    	final String productId = args.getString(0);

    		if (myInventory != null) {
    	    	// Set up the activity result callback to this class
    	    	cordova.setActivityResultCallback(this);
                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        buy(productId);
                    }
                });

    		} else {
	    		// Initialize
	        	cordova.getThreadPool().execute(new Runnable() {
	                public void run() {
	                	List<String> sku = new ArrayList<String>();
	                	sku.add(0, productId);
	                	init(sku);
	                }
	            });
	    	}
    		return true;
    	} else if (action.equalsIgnoreCase("consumePurchase")) {
    		
    		// Retain callback and wait
    		consumeCbContext = callbackContext;
    		PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
    		result.setKeepCallback(true);
            consumeCbContext.sendPluginResult(result);
    		
    		if (myInventory != null) {
    	    	// Consume product
    			consumePurchase(args);
    		} else {
	    		// Initialize
	        	cordova.getThreadPool().execute(new Runnable() {
	                public void run() {
	                	List<String> sku = new ArrayList<String>();
	                	init(sku);
	                }
	            });
	    	}
    		return true;
    	}
		return false;
    }
    
    // Initialize the plugin
 	private void init(final List<String> skus){
 		Log.d(TAG, "init start ");
 		// Some sanity checks to see if the developer (that's you!) really followed the
        // instructions to run this plugin
 	 	if (base64EncodedPublicKey == null || base64EncodedPublicKey.isEmpty()) {
 	 		throw new RuntimeException("Please put your app's public key in res/values/billing_key.xml."); 	 		
 	 	}
 	 	
 	 	// Create the helper, passing it our context and the public key to verify signatures with
        Log.d(TAG, "Creating IAB helper.");
        mHelper = new IabHelper(cordova.getActivity(), base64EncodedPublicKey);
        
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
            		
                	if (restoreAllCbContext != null) {
                		restoreAllCbContext.error(errorMsg);
                	} else if (productDetailCbContext != null) {
                		productDetailCbContext.error(errorMsg);
                	} else if (getPendingCbContext != null) {
                		getPendingCbContext.error(errorMsg);
                	} else if (makePurchaseCbContext != null) {
                		makePurchaseCbContext.error(errorMsg);
                	} else if (getPendingCbContext != null) {
                		getPendingCbContext.error(errorMsg);
                	} else if (consumeCbContext != null) {
                		consumeCbContext.error(errorMsg);
                	}

                	return;
                }

                if (makePurchaseCbContext != null) {
                	// This is a purchase request
                	buy(skus.get(0));
                	return;
                }
                
                // Hooray, IAB is fully set up. Now, let's get an inventory of stuff we own.
                if (skus.size() <= 0){
                	Log.d(TAG, "Setup successful. Querying inventory.");
                	mHelper.queryInventoryAsync(mGotInventoryListener);
 				} else {
 					Log.d(TAG, "Setup successful. Querying inventory w/ SKUs.");
 					mHelper.queryInventoryAsync(true, skus, mGotDetailsListener);
 				}
             }			
        });
    }
 	
 	// Buy an item
 	private void buy(final String sku) {
 		/* TODO: for security, generate your payload here for verification. See the comments on 
         *        verifyDeveloperPayload() for more info. Since this is a sample, we just use 
         *        an empty string, but on a production application you should generate this. 
         */
 		final String payload = "";

 		mHelper.launchPurchaseFlow(cordova.getActivity(), sku, RC_REQUEST, 
                 mPurchaseFinishedListener, payload);
 	}
 	
 	// Consume a purchase
 	private void consumePurchase(JSONArray data) throws JSONException{
 		JSONArray sku = data.getJSONArray(0);
        Log.d(TAG, "fetching item: " + sku.getString(0));
 		// Get the purchase from the inventory
 		Purchase purchase = myInventory.getPurchase(sku.getString(0));
        Log.d(TAG, "purchase is: " + purchase.toString());
 		if (purchase != null) {
 			// Consume it
 			mHelper.consumeAsync(purchase, mConsumeFinishedListener);
 		} else {
 			if (consumeCbContext != null) {
 	 			consumeCbContext.error("notConsumable");
 	 			consumeCbContext = null;
 			}
 		}
 	}
 	
 	// Get the list of purchases
 	private JSONArray getPurchases() throws JSONException {
 		// Get the list of owned items
        List<Purchase>purchaseList = myInventory.getAllPurchases();

        // Convert the java list to json
        JSONArray jsonPurchaseList = new JSONArray();
        for (Purchase p : purchaseList) {
 	       jsonPurchaseList.put(new JSONObject(p.getOriginalJson()));
        }

        return jsonPurchaseList;
 	}
 	
 	// Get SkuDetails for skus
	private void getProductDetails(final List<String> skus){
		Log.d(TAG, "Querying inventory w/ SKUs.");
		mHelper.queryInventoryAsync(true, skus, mGotDetailsListener);
	}

 	// Listener that's called when we finish querying the items and subscriptions we own
    IabHelper.QueryInventoryFinishedListener mGotInventoryListener = new IabHelper.QueryInventoryFinishedListener() {
        public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
        	Log.d(TAG, "Inside mGotInventoryListener");
        	if (!hasErrorsAndUpdateInventory(result, inventory)) { }

            Log.d(TAG, "Query inventory was successful.");
            
            if (restoreAllCbContext != null) {
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
                        pendingObject.putOpt("receipt", skuObject.getString("purchaseToken"));
                        pendingObject.putOpt("packageName", skuObject.getString("packageName"));
                        pendingObject.putOpt("productId", skuObject.getString("productId"));

                        // Add new object into array
                        skuList.put(pendingObject);
                    }
				} catch (JSONException e) { }

	    		// Return result
	    		restoreAllCbContext.success(skuList);
	    		restoreAllCbContext = null;
            }
        }
    };
    
    // Listener that's called when we finish querying the details
    IabHelper.QueryInventoryFinishedListener mGotDetailsListener = new IabHelper.QueryInventoryFinishedListener() {
        public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
            Log.d(TAG, "Inside mGotDetailsListener");
            if (!hasErrorsAndUpdateInventory(result, inventory)) { }

            Log.d(TAG, "Query details was successful.");

            if (productDetailCbContext != null) {

	            List<SkuDetails>skuList = inventory.getAllProducts();
	            
	            // Convert the java list to JSON
	            JSONObject skusObject = new JSONObject();
	            
	            try {
	                for (SkuDetails sku : skuList) {
	                    Log.d(TAG, "SKUDetails: Title: " + sku.getTitle());
	                    
	                	JSONObject skuObject = new JSONObject();
	                    skuObject.put("productId", sku.getSku());
	                    skuObject.put("price", sku.getPrice());
	                    skuObject.put("description", sku.getDescription());
	                    skuObject.put("name", sku.getTitle());
	                    skusObject.put(sku.getSku(), skuObject);
	                }
	            } catch (JSONException e) {}
            
            	productDetailCbContext.success(skusObject);
            	productDetailCbContext = null;
            }
        }
    };
    
    // Check if there is any errors in the iabResult and update the inventory
    private Boolean hasErrorsAndUpdateInventory(IabResult result, Inventory inventory) {
    	Log.d(TAG, "Update Inventory");
    	if (result.isFailure()) {
            if (restoreAllCbContext != null) {
	    		// Return result
	    		restoreAllCbContext.error("Failed to query inventory: " + result);
	    		restoreAllCbContext = null;
            }    		
        	return true;
        }

        // Update the inventory
        myInventory = inventory;
        
        return false;
    }
    
    // Callback for when a purchase is finished
    IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener() {
        public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
            Log.d(TAG, "Purchase finished: " + result + ", purchase: " + purchase);

            if (makePurchaseCbContext != null) {         
            	
                if (result.isFailure()) {
                	String errMsg = "unknownError";
                	switch (result.getResponse()) {
                		case -1005:
                			errMsg = "userCancelled";
                            break;
                		case 7:
                			errMsg = "alreadyOwned";
                            break;
                	}
                	
                	makePurchaseCbContext.error(errMsg);
                	makePurchaseCbContext = null;
                	return;
                }
                
                Log.d(TAG, "Purchase successful.");
                
            	JSONObject purchaseResult = new JSONObject();
            	try {
					purchaseResult.put("paltform", "android");
					purchaseResult.put("receipt", purchase.getToken());
					purchaseResult.put("productId", purchase.getSku());
					purchaseResult.put("packageName", cordova.getActivity().getPackageName());
            		makePurchaseCbContext.success(purchaseResult);
            	} catch (JSONException e) { }
            	makePurchaseCbContext = null;
            }

            /*
            if (!verifyDeveloperPayload(purchase)) {
            	Log.d(TAG, "cannot verifiy purchase");
            	// TODO: callbackContext.error("Error purchasing. Authenticity verification failed.");
                return;
            }
            */
            // Add the purchase to the inventory
            myInventory.addPurchase(purchase);
            
        }
    };
    
    // Called when consumption is complete
    IabHelper.OnConsumeFinishedListener mConsumeFinishedListener = new IabHelper.OnConsumeFinishedListener() {
        public void onConsumeFinished(Purchase purchase, IabResult result) {
            Log.d(TAG, "Consumption finished. Purchase: " + purchase + ", result: " + result);

            // We know this is the "gas" sku because it's the only one we consume,
            // so we don't check which sku was consumed. If you have more than one
            // sku, you probably should check...
            if (result.isSuccess()) {
                // successfully consumed, so we apply the effects of the item in our
                // game world's logic
            	
                // remove the item from the inventory
            	myInventory.erasePurchase(purchase.getSku());
                Log.d(TAG, "Consumption successful. .");
                
                if (consumeCbContext != null) {
     	 			consumeCbContext.success();
     	 			consumeCbContext = null;
     			}
                
            } else {
            	if (consumeCbContext != null) {
     	 			consumeCbContext.error("Error while consuming: " + result);
     	 			consumeCbContext = null;
     			}
            }
        }
    };
    
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
