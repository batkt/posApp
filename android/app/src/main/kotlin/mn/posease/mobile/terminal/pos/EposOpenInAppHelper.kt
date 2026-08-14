package mn.posease.mobile.terminal.pos

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import mn.databank.eposopenapi.factory.EposTransAPIFactory
import mn.databank.eposopenapi.factory.IEposTransAPI
import mn.databank.eposopenapi.message.HealthCheckMsg
import mn.databank.eposopenapi.message.MessageUtils
import mn.databank.eposopenapi.message.PrintBitmapMsg
import mn.databank.eposopenapi.message.SaleNoReceiptMsg
import mn.databank.eposopenapi.message.TaskResponse
import mn.databank.eposopenapi.message.TransResponse
import mn.databank.eposopenapi.sdkconstants.SdkConstants
import org.json.JSONObject
import kotlin.math.roundToLong

/**
 * Data Bank EPOS Open API running **inside** PosEase (same pattern as parkeasev1).
 * Used on PAX A930 / A8900 per [TerminalHardwareProfile.EPOS_OPEN_IN_APP].
 */
class EposOpenInAppHelper(
    private val activity: Activity,
    private val logTag: String,
) {
    private val api: IEposTransAPI = EposTransAPIFactory.createTransAPI()

    /**
     * [IEposTransAPI.startTrans] returns whether the SDK actually accepted and
     * started the transaction — when it returns false, no [onResult]/activity
     * result ever arrives, so a caller that ignores this return value is left
     * waiting forever on a pending [MethodChannel.Result] that will never
     * resolve. All three start* methods below surface it so [MainActivity] can
     * fail fast instead of hanging.
     */
    fun startHealthCheck(): Boolean {
        Log.i(logTag, "EPOS in-app health check")
        val request = HealthCheckMsg.Request()
        val args = Bundle()
        args.putString("request-type", "healthCheck")
        request.setExtraBundle(args)
        request.setCategory(SdkConstants.CATEGORY_HEALTH_CHECK)
        val started = api.startTrans(activity, request)
        if (!started) Log.e(logTag, "EPOS in-app health check: startTrans returned false")
        return started
    }

    fun startPrintBitmap(base64Image: String?): Boolean {
        Log.i(logTag, "EPOS in-app printBitmap")
        val request = PrintBitmapMsg.Request()
        val args = Bundle()
        request.setExtraBundle(args)
        request.setBitmap(base64Image)
        request.setCategory(SdkConstants.CATEGORY_PRINT_BITMAP)
        val started = api.startTrans(activity, request)
        if (!started) Log.e(logTag, "EPOS in-app printBitmap: startTrans returned false")
        return started
    }

    /**
     * Card sale without receipt — matches parkeasev1 [SaleNoReceiptMsg] flow.
     * [amountMinor] is amount in **minor units** (e.g. tögrög × 100).
     */
    fun startSaleNoReceipt(amountMinor: Long, dbRefNo: String?): Boolean {
        Log.i(logTag, "EPOS in-app saleNoReceipt amountMinor=$amountMinor dbRefNo=$dbRefNo")
        val request = SaleNoReceiptMsg.Request()
        val args = Bundle()
        request.setExtraBundle(args)
        request.setAmount(amountMinor)
        if (!dbRefNo.isNullOrBlank()) {
            request.setDbRefNo(dbRefNo)
        }
        request.setCategory(SdkConstants.CATEGORY_SALE)
        val started = api.startTrans(activity, request)
        if (!started) Log.e(logTag, "EPOS in-app saleNoReceipt: startTrans returned false")
        return started
    }

    /**
     * @return true if this result belonged to EPOS Open API and [pending] was completed.
     */
    fun tryDeliverActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
        pending: MethodChannel.Result,
    ): Boolean {
        val baseResponse = api.onResult(requestCode, resultCode, data) ?: return false
        when (baseResponse) {
            is HealthCheckMsg.Response -> {
                val jo = JSONObject()
                jo.put("rspCode", "000")
                jo.put("rspMsg", "OK")
                jo.put("raw", baseResponse.toString())
                pending.success(jsonObjectToMap(jo))
            }
            is TransResponse -> {
                val response = baseResponse
                val jo = JSONObject()
                jo.put("merchantName", response.merchantName ?: "")
                jo.put("merchantId", response.merchantId ?: "")
                jo.put("terminalId", response.terminalId ?: "")
                jo.put("cardNo", response.cardNo ?: "")
                jo.put("dbRefNo", response.dbRefNo ?: "")
                jo.put("refNo", response.refNo ?: "")
                jo.put("traceNo", response.traceNo ?: 0)
                jo.put("authCode", response.authCode ?: "")
                jo.put("rspCode", response.rspCode ?: 0)
                jo.put("rspMsg", response.rspMsg ?: "")
                jo.put("amount", response.amount ?: 0)
                jo.put("transTime", response.transTime ?: "")
                jo.put("cardType", response.cardType ?: "")
                jo.put("batchNo", response.batchNo ?: "")
                jo.put("issuerName", response.issuerName ?: "")
                jo.put("acquirerName", response.acquirerName ?: "")
                response.hasLoyalty?.let { jo.put("hasLoyalty", it) }
                response.noTxnAmount?.let { jo.put("noTxnAmount", it) }
                response.yesTxnAmount?.let { jo.put("yesTxnAmount", it) }
                response.usableLp?.let { jo.put("usableLp", it) }
                response.loyaltyProviderName?.let { jo.put("loyaltyProviderName", it) }
                val codeVal = response.rspCode ?: 0
                val ok = codeVal == 0 || codeVal.toString() == "000"
                if (ok) {
                    jo.put("paymentType", "CARD")
                }
                jo.put("result", jo.toString())
                pending.success(jsonObjectToMap(jo))
            }
            is TaskResponse -> {
                // Matches Flutter [PrinterService] expectation for `android.epos.tasks.printBitmap`.
                pending.success("printed")
            }
            else -> {
                val jo = JSONObject()
                jo.put("rspCode", "000")
                jo.put("raw", baseResponse.toString())
                pending.success(jsonObjectToMap(jo))
            }
        }
        return true
    }

    private fun jsonObjectToMap(jo: JSONObject): HashMap<String, Any?> {
        val out = HashMap<String, Any?>()
        val it = jo.keys()
        while (it.hasNext()) {
            val k = it.next()
            out[k] = jo.get(k)
        }
        return out
    }

    companion object {
        fun amountDoubleToMinorUnits(amountTugrik: Double): Long =
            (amountTugrik * 100.0).roundToLong()
    }
}
