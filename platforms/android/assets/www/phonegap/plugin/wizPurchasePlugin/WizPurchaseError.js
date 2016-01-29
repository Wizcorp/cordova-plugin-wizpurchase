cordova.define("jp.wizcorp.phonegap.plugin.wizPurchase.WizPurchaseError", function(require, exports, module) { /*
 * The MIT License (MIT)
 *
 * Copyright (c) 2016 Wizcorp Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
*/

/**
 * WizPurchaseError
 */
function WizPurchaseError(error) {
  this.code = error || null;
}

// WizPurchase error codes
WizPurchaseError.UNKNOWN_ERROR = 1;
WizPurchaseError.ARGS_TYPE_MISMATCH = 2;
WizPurchaseError.ARGS_ARITY_MISMATCH = 3;
WizPurchaseError.IOS_VERSION_ERR = 4;
WizPurchaseError.INVALID_RECEIPT = 5;
WizPurchaseError.INVALID_TRANSACTION_STATE = 6;
WizPurchaseError.PURCHASE_NOT_FOUND = 7;
WizPurchaseError.PURCHASE_NOT_PENDING = 8;
WizPurchaseError.REMOTE_EXCEPTION = 9;
WizPurchaseError.BAD_RESPONSE= 10;
WizPurchaseError.BAD_SIGNATURE= 11;
WizPurchaseError.SEND_INTENT_FAILED = 12;
WizPurchaseError.USER_CANCELLED = 13;
WizPurchaseError.INVALID_PURCHASE = 14;
WizPurchaseError.MISSING_TOKEN = 15;
WizPurchaseError.NO_SUBSCRIPTIONS = 16;
WizPurchaseError.INVALID_CONSUMPTION = 17;
WizPurchaseError.CANNOT_PURCHASE = 18;
WizPurchaseError.UNKNOWN_PRODUCT_ID = 19;
WizPurchaseError.ALREADY_OWNED = 20;
WizPurchaseError.NOT_OWNED = 21;
WizPurchaseError.INVALID_CLIENT = 22;
WizPurchaseError.INVALID_PAYMENT = 23;
WizPurchaseError.UNAUTHORIZED = 24;
WizPurchaseError.RECEIPT_REFRESH_FAILED = 25;

module.exports = WizPurchaseError;
});