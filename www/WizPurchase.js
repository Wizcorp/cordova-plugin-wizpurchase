var exec = require("cordova/exec");

var WizPurchase = {
	getProductDetails: function (productIds, s, f) {
		if (!productIds) {
			return s();
		}
		if (!Array.isArray(productIds)) {
			productIds = [ productIds ];
		}
		exec(s, f, "WizPurchase", "getProductDetails", [ productIds ]);
	},

	makePurchase: function(productId, s, f) {
		if (!productId) {
			return f("noProductId");
		}
		exec(s, f, "WizPurchase", "makePurchase", [ productId ]);
	},

	finishPurchase: function(productId, isConsumable, s, f) {
		if (!productId) {
			return s();
		}
		if (typeof isConsumable !== 'boolean') {
			return f(WizPurchaseError.ARGS_TYPE_MISMATCH);
		}
		exec(s, f, "WizPurchase", "finishPurchase", [ productId, isConsumable ]);
	},

	getPendingPurchases: function (s, f) {
		exec(s, f, "WizPurchase", "getPendingPurchases", []);
	},

	restoreAllPurchases: function (s, f) {
		exec(s, f, "WizPurchase", "restoreAllPurchases", []);
	},

	refreshReceipt: function (s, f) {
		exec(s, f, "WizPurchase", "refreshReceipt", []);
	},

	setApplicationUsername: function (applicationUsername, s, f) {
		exec(s, f, "WizPurchase", "setApplicationUsername", [ applicationUsername ]);
	}
};

module.exports = WizPurchase;
