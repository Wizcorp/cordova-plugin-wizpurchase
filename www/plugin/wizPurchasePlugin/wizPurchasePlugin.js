cordova.define("jp.wizcorp.phonegap.plugin.wizPurchasePlugin", function(require, exports, module) {

	var exec = require("cordova/exec");
	var wizPurchase = {
	
	    getProductDetails: function (productIds, s, f) {
	        if (!productIds) {
	            return s({});
	        }
	        exec(s, f, "wizPurchasePlugin", "getProductDetails", [ productIds ]);	
	    },
	
	    makePurchase: function(productId, s, f) {
	        if (!productId) {
	            return f("ProductId can't be null");
	        }
	        exec(s, f, "wizPurchasePlugin", "makePurchase", productId);		
	    },
	    
	    consumePurchase: function (receipt, s, f) {
	        if (!receipt) {
	            return s();
	        }
	
	        exec(s, f, "wizPurchasePlugin", "consumePurchase", [ receipt ]);
	    },
	    
	    getPurchases: function (s, f) {
	        exec(s, f, "wizPurchasePlugin", "getPurchases", []);
	    }
	};

	module.exports = wizPurchase;
});