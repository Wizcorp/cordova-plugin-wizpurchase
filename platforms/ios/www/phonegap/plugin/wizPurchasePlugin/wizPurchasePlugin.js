cordova.define("jp.wizcorp.phonegap.plugin.wizPurchase.wizPurchase", function(require, exports, module) {
	var exec = require("cordova/exec");
	var wizPurchase = {
		getProductDetails: function (productIds, s, f) {
			if (!productIds) {
				return s();
			}
			if (!Array.isArray(productIds)) {
				productIds = [ productIds ];
			}
			exec(s, f, "wizPurchasePlugin", "getProductDetails", [ productIds ]);
		},

		makePurchase: function(productId, s, f) {
			if (!productId) {
				return f("noProductId");
			}
			exec(s, f, "wizPurchasePlugin", "makePurchase", [ productId ]);
		},

		finishPurchase: function(productId, isConsumable, s, f) {
			if (!productId) {
				return s();
			}
			if (typeof isConsumable !== 'boolean') {
				return f(WizPurchaseError.ARGS_TYPE_MISMATCH);
			}
			exec(s, f, "wizPurchasePlugin", "finishPurchase", [ productId, isConsumable ]);
		},

		getPendingPurchases: function (s, f) {
			exec(s, f, "wizPurchasePlugin", "getPendingPurchases", []);
		},

		restoreAllPurchases: function (s, f) {
			exec(s, f, "wizPurchasePlugin", "restoreAllPurchases", []);
		}
	};

	module.exports = wizPurchase;
});
