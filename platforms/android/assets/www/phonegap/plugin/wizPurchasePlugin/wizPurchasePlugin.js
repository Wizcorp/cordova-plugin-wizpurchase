cordova.define("jp.wizcorp.phonegap.plugin.wizPurchasePlugin", function(require, exports, module) {

	var exec = require("cordova/exec");
	var wizPurchase = {
	
	    getProductDetail: function (productIds, s, f) {
	        if (!productIds || productIds.length == 0) {
	            return s({});
	        }
	        if (Object.prototype.toString.call(productIds) === '[object String]') {
	        	// In the event one productId is passed in as String we shall put it in
	        	// an array to be easily dealt with natively.
		        productIds = [ productIds ];
	        }
	        exec(s, f, "wizPurchasePlugin", "getProductDetail", [ productIds ]);	
	    },
	
	    canMakePurchase: function(s, f) {
	        exec(s, f, "wizPurchasePlugin", "canMakePurchase", []);		
	    },
	
	    makePurchase: function(productId, s, f) {
	        if (!productId) {
	            return f("noProductId");
	        }
	        exec(s, f, "wizPurchasePlugin", "makePurchase", [ productId ]);		
	    },
	    
	    consumePurchase: function (receipt, s, f) {
	        if (!receipt || receipt.length == 0) {
	            return s();
	        }
	        if (Object.prototype.toString.call(receipt) === '[object String]') {
	        	// In the event one receipt is passed in as String we shall put it in
	        	// an array to be easily dealt with natively.
		        receipt = [ receipt ];
	        }
	       
	        exec(s, f, "wizPurchasePlugin", "consumePurchase", [ receipt ]);
	    },
	    
	    getPending: function (s, f) {
	        exec(s, f, "wizPurchasePlugin", "getPending", []);
	    },
	    
	    restoreAll: function (s, f) {
	        exec(s, f, "wizPurchasePlugin", "restoreAll", []);
	    }
	};

	module.exports = wizPurchase;
});
