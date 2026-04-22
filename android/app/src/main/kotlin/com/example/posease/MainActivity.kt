package com.posease.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import kotlin.math.max
import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.lang.ClassNotFoundException
import java.lang.IllegalStateException
import java.util.Locale
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.posease.app"
    private val eposLogTag = "PosEaseEpos"
    /**
     * Known UniPOS package ids; [resolveUniPosTargetPackage] also scans SEND text/plain handlers
     * so other bank/PAX-shipped terminal apps can be found without hardcoding every id.
     */
    private val uniPosPackageCandidates = listOf(
        "mn.genesis.unipos.terminal",
    )
    private val uniPosRequestCode = 9301
    private val eposRequestCode = 9302
    private var pendingUniPosResult: MethodChannel.Result? = null
    private var pendingEposResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "android.epos.tasks.printBitmap" -> {
                        val base64 = call.argument<String>("base64")
                        if (base64.isNullOrEmpty()) {
                            result.error("ARG_ERROR", "base64 is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bitmap = decodeBase64ToBitmap(base64)
                            if (bitmap == null) {
                                result.error("DECODE_ERROR", "Failed to decode bitmap", null)
                                return@setMethodCallHandler
                            }
                            printBitmapOnPax(bitmap)
                            result.success("printed")
                        } catch (e: Throwable) {
                            result.error("PRINT_ERROR", e.message, null)
                        }
                    }
                    "android.epos.tasks.testPrint" -> {
                        try {
                            val text = call.argument<String>("text")
                            val bitmap = buildTestBitmap(text)
                            val preferred = call.argument<String>("packageName")
                            // EPOS/Databank SEND first — same interoperable path as most POS terminals.
                            val targetEposPackage = resolveEposTargetPackage(preferred)
                            if (targetEposPackage != null) {
                                if (pendingEposResult != null) {
                                    result.error("BUSY", "EPOS request already in progress", null)
                                    return@setMethodCallHandler
                                }
                                val base64 = bitmapToBase64(bitmap)
                                val payload = JSONObject().apply {
                                    put("category", "android.epos.payment.printBitmap")
                                    put("commandType", "28")
                                    put("amount", "1.00")
                                    put("dbRefNo", System.currentTimeMillis().toString())
                                    put("bitmap", base64)
                                }
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, payload.toString())
                                    setPackage(targetEposPackage)
                                }
                                if (intent.resolveActivity(packageManager) != null) {
                                    pendingEposResult = result
                                    @Suppress("DEPRECATION")
                                    startActivityForResult(intent, eposRequestCode)
                                    return@setMethodCallHandler
                                }
                            }

                            // No EPOS handler (or intent not resolvable): built-in PAX Neptune.
                            printBitmapOnPax(bitmap)
                            result.success("printed")
                        } catch (e: Throwable) {
                            result.error("PRINT_ERROR", e.message, null)
                        }
                    }
                    "android.unipos.purchase" -> {
                        try {
                            val amountAny = call.argument<Number>("amount")
                            val amount = amountAny?.toDouble()
                            val code = call.argument<String>("code") ?: "NormalPurchase"
                            val originalIdAny = call.argument<Number>("originalId")
                            val originalId = originalIdAny?.toLong() ?: 0L
                            if (amount == null || amount <= 0.0) {
                                result.error("ARG_ERROR", "amount must be > 0", null)
                                return@setMethodCallHandler
                            }
                            val purchaseJson = JSONObject().apply {
                                put("amount", amount)
                                put("code", code)
                                put("originalId", originalId)
                            }
                            val requestJson = JSONObject().apply {
                                put("command", "PURCHASE")
                                put("purchase", purchaseJson)
                            }
                            val preferred = call.argument<String>("packageName")
                            launchUniPos(requestJson.toString(), result, preferred)
                        } catch (e: Throwable) {
                            result.error("UNIPOS_ERROR", e.message, null)
                        }
                    }
                    "android.unipos.void" -> {
                        try {
                            val invoiceNoAny = call.argument<Number>("invoiceNo")
                            val invoiceNo = invoiceNoAny?.toLong()
                            if (invoiceNo == null) {
                                result.error("ARG_ERROR", "invoiceNo is required", null)
                                return@setMethodCallHandler
                            }
                            val requestJson = JSONObject().apply {
                                put("command", "VOID")
                                put("invoiceNo", invoiceNo)
                            }
                            val preferred = call.argument<String>("packageName")
                            launchUniPos(requestJson.toString(), result, preferred)
                        } catch (e: Throwable) {
                            result.error("UNIPOS_ERROR", e.message, null)
                        }
                    }
                    "android.unipos.settlement" -> {
                        val preferred = call.argument<String>("packageName")
                        val requestJson = JSONObject().apply {
                            put("command", "SETTLEMENT")
                        }
                        launchUniPos(requestJson.toString(), result, preferred)
                    }
                    "android.epos.payment.printBitmap" -> {
                        try {
                            val base64 = call.argument<String>("base64")
                            if (base64.isNullOrEmpty()) {
                                result.error("ARG_ERROR", "base64 is required", null)
                                return@setMethodCallHandler
                            }
                            val amount = call.argument<String>("amount") ?: "0.00"
                            val dbRefNo = call.argument<String>("dbRefNo")
                                ?: System.currentTimeMillis().toString()
                            val payload = JSONObject().apply {
                                put("category", "android.epos.payment.printBitmap")
                                put("commandType", "28")
                                put("amount", amount)
                                put("dbRefNo", dbRefNo)
                                put("bitmap", base64)
                            }
                            val preferred = call.argument<String>("packageName")
                            launchEpos(payload.toString(), result, preferred)
                        } catch (e: Throwable) {
                            result.error("EPOS_ERROR", e.message, null)
                        }
                    }
                    "android.epos.payment.healthCheck" -> {
                        try {
                            // Match epossdk.md §1.6.1: Java sets only CATEGORY_HEALTH_CHECK + empty Bundle.
                            // SEND JSON: category only (no commandType/dbRefNo/request-type — EPOS may reject extras).
                            val payload = JSONObject().apply {
                                put("category", "android.epos.payment.healthCheck")
                            }
                            val preferred = call.argument<String>("packageName")
                            launchEpos(payload.toString(), result, preferred)
                        } catch (e: Throwable) {
                            result.error("EPOS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchUniPos(
        request: String,
        result: MethodChannel.Result,
        preferredPackage: String? = null,
    ) {
        if (pendingUniPosResult != null) {
            result.error("BUSY", "UniPOS request already in progress", null)
            return
        }
        val targetPackage = resolveUniPosTargetPackage(preferredPackage)
        if (targetPackage == null) {
            result.error(
                "UNIPOS_NOT_FOUND",
                "No UniPOS / card terminal app found. Install UniPOS or pass packageName from the app.",
                null,
            )
            return
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, request)
            setPackage(targetPackage)
        }
        val canResolve = intent.resolveActivity(packageManager) != null
        if (!canResolve) {
            result.error(
                "UNIPOS_NOT_FOUND",
                "Terminal package $targetPackage cannot handle payment intent.",
                null,
            )
            return
        }
        pendingUniPosResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, uniPosRequestCode)
    }

    private fun resolveUniPosTargetPackage(preferred: String?): String? {
        val mine = applicationContext.packageName
        val ordered = mutableListOf<String>()
        preferred?.trim()?.takeIf { it.isNotEmpty() }?.let { ordered.add(it) }
        ordered.addAll(uniPosPackageCandidates)
        for (pkg in ordered.distinct()) {
            if (pkg == mine) continue
            if (isPackageInstalled(pkg) && canUniPosHandleSend(pkg)) return pkg
        }
        // 1) Prefer known terminal-like packages (UniPOS/EPOS/etc)
        discoverUniPosFromSendHandlers(mine)?.let { return it }
        // 2) Fallback: any other third-party SEND handler except our own app/browser.
        return discoverAnyTerminalFromSendHandlers(mine)
    }

    private fun launchEpos(
        request: String,
        result: MethodChannel.Result,
        preferredPackage: String? = null,
    ) {
        if (pendingEposResult != null) {
            result.error("BUSY", "EPOS request already in progress", null)
            return
        }
        val targetPackage = resolveEposTargetPackage(preferredPackage)
        if (targetPackage == null) {
            result.error(
                "EPOS_NOT_FOUND",
                "No EPOS terminal app found. Install EPOS Open SDK app or pass packageName.",
                null,
            )
            return
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, request)
            setPackage(targetPackage)
        }
        val canResolve = intent.resolveActivity(packageManager) != null
        if (!canResolve) {
            result.error(
                "EPOS_NOT_FOUND",
                "EPOS package $targetPackage cannot handle payment intent.",
                null,
            )
            return
        }
        pendingEposResult = result
        Log.d(eposLogTag, "launchEpos package=$targetPackage EXTRA_TEXT=$request")
        @Suppress("DEPRECATION")
        startActivityForResult(intent, eposRequestCode)
    }

    private fun resolveEposTargetPackage(preferred: String?): String? {
        val mine = applicationContext.packageName
        val preferredPkg = preferred?.trim()?.takeIf { it.isNotEmpty() }
        if (preferredPkg != null && preferredPkg != mine && canUniPosHandleSend(preferredPkg)) {
            return preferredPkg
        }
        val probe = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }
        val infos = packageManager.queryIntentActivities(
            probe,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return infos.asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it != mine }
            .firstOrNull { pkg ->
                val p = pkg.lowercase(Locale.US)
                (p.contains("epos") || p.contains("databank")) && canUniPosHandleSend(pkg)
            }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun canUniPosHandleSend(packageName: String): Boolean {
        val probe = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            setPackage(packageName)
        }
        return probe.resolveActivity(packageManager) != null
    }

    private fun discoverUniPosFromSendHandlers(excludePackage: String): String? {
        val probe = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }
        val infos = packageManager.queryIntentActivities(
            probe,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return infos.asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it != excludePackage }
            .filter { isLikelyUniPosPackage(it) }
            .firstOrNull { canUniPosHandleSend(it) }
    }

    private fun discoverAnyTerminalFromSendHandlers(excludePackage: String): String? {
        val probe = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }
        val infos = packageManager.queryIntentActivities(
            probe,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return infos.asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it != excludePackage }
            .filterNot { isProbablyGenericShareTarget(it) }
            .firstOrNull { canUniPosHandleSend(it) }
    }

    private fun isLikelyUniPosPackage(pkg: String): Boolean {
        val p = pkg.lowercase(Locale.US)
        if (p.contains("unipos")) return true
        if (p.contains("genesis") && p.contains("terminal")) return true
        if (p.contains("epos")) return true
        if (p.contains("databank")) return true
        if (p.contains("pax")) return true
        if (p.contains("newpos")) return true
        if (p.contains("sunmi")) return true
        if (p.contains("verifone")) return true
        if (p.contains("ingenico")) return true
        if (p.contains("castles")) return true
        if (p.contains("terminal") && (p.contains("pos") || p.contains("pay"))) return true
        return false
    }

    private fun isProbablyGenericShareTarget(pkg: String): Boolean {
        val p = pkg.lowercase(Locale.US)
        if (p.contains("android")) return true
        if (p.contains("google")) return true
        if (p.contains("chrome")) return true
        if (p.contains("samsung")) return true
        if (p.contains("microsoft")) return true
        if (p.contains("whatsapp")) return true
        if (p.contains("telegram")) return true
        if (p.contains("facebook")) return true
        if (p.contains("messenger")) return true
        if (p.contains("instagram")) return true
        return false
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == uniPosRequestCode) {
            val pending = pendingUniPosResult ?: return
            pendingUniPosResult = null

            val payload = hashMapOf<String, Any?>(
                "resultCode" to resultCode,
                "command" to data?.getStringExtra("command"),
                "result" to data?.getStringExtra("result"),
                "paymentType" to data?.getStringExtra("paymentType"),
                "error" to data?.getStringExtra("error"),
            )
            if (resultCode == Activity.RESULT_OK) {
                pending.success(payload)
            } else {
                val errorMessage = data?.getStringExtra("error")
                    ?: "UniPOS request canceled/failed"
                pending.error("UNIPOS_FAILED", errorMessage, payload)
            }
            return
        }

        if (requestCode == eposRequestCode) {
            val pending = pendingEposResult ?: return
            pendingEposResult = null

            val payload = hashMapOf<String, Any?>(
                "resultCode" to resultCode
            )
            fun mergeEposJsonString(raw: String?) {
                if (raw.isNullOrBlank()) return
                try {
                    val jo = JSONObject(raw)
                    val it = jo.keys()
                    while (it.hasNext()) {
                        val k = it.next()
                        val v = jo.get(k)
                        payload[k] = when (v) {
                            is JSONObject -> v.toString()
                            is org.json.JSONArray -> v.toString()
                            org.json.JSONObject.NULL -> null
                            else -> v
                        }
                    }
                } catch (_: Exception) {
                }
            }
            // EPOS often returns BaseResponse / jsonRet as JSON in a string extra, not only flat extras.
            mergeEposJsonString(data?.getStringExtra(Intent.EXTRA_TEXT))
            mergeEposJsonString(data?.getStringExtra("jsonRet"))
            mergeEposJsonString(data?.getStringExtra("result"))
            data?.extras?.let { extras ->
                for (key in extras.keySet()) {
                    if (!payload.containsKey(key)) {
                        payload[key] = extras.get(key)
                    }
                }
            }
            Log.d(eposLogTag, "onActivityResult epos activityResultCode=$resultCode payload=$payload")
            if (resultCode == Activity.RESULT_OK) {
                pending.success(payload)
            } else {
                val errorMessage = (payload["rspMsg"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
                    ?: data?.getStringExtra("rspMsg")
                    ?: data?.getStringExtra("error")
                    ?: "EPOS request canceled/failed"
                pending.error("EPOS_FAILED", errorMessage, payload)
            }
        }
    }

    private fun decodeBase64ToBitmap(base64Data: String): Bitmap? {
        val bytes = Base64.decode(base64Data, Base64.DEFAULT)
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    /**
     * Thermal printers need 1-bit contrast: resize to ~384px width (58mm head) and
     * threshold to pure black/white so anti-aliased grays do not print as fuzzy dots.
     */
    private fun prepareReceiptBitmapForPrinter(src: Bitmap): Bitmap {
        val targetW = 384
        val toProcess = if (src.width > targetW) {
            val ratio = targetW.toFloat() / src.width
            val nh = max(1, (src.height * ratio).toInt())
            Bitmap.createScaledBitmap(src, targetW, nh, true)
        } else {
            src
        }
        val w = toProcess.width
        val h = toProcess.height
        val pixels = IntArray(w * h)
        toProcess.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val c = pixels[i]
            val a = Color.alpha(c)
            pixels[i] = if (a < 28) {
                Color.WHITE
            } else {
                val lum = Color.red(c) * 0.299 + Color.green(c) * 0.587 + Color.blue(c) * 0.114
                if (lum < 172.0) Color.BLACK else Color.WHITE
            }
        }
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        out.setPixels(pixels, 0, w, 0, 0, w, h)
        if (toProcess !== src && !toProcess.isRecycled) {
            toProcess.recycle()
        }
        return out
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    private fun printBitmapOnPax(bitmap: Bitmap) {
        val toPrint = prepareReceiptBitmapForPrinter(bitmap)
        if (toPrint !== bitmap) {
            bitmap.recycle()
        }
        try {
            val neptuneClass = Class.forName("com.pax.neptunelite.api.NeptuneLiteUser")
            val neptune = neptuneClass.getMethod("getInstance").invoke(null)
                ?: throw IllegalStateException("NeptuneLiteUser.getInstance() returned null")
            val dal = resolveDalWithFallback(neptuneClass, neptune)

            val dalClass = dal.javaClass
            val getPrinter = dalClass.getMethod("getPrinter")
            val printer = getPrinter.invoke(dal)
                ?: throw IllegalStateException("DAL returned null printer instance")

            val printerClass = printer.javaClass
            try {
                printerClass.getMethod("init").invoke(printer)
            } catch (_: Throwable) {}

            try {
                printerClass.getMethod("printBitmap", Bitmap::class.java).invoke(printer, toPrint)
            } catch (_: Throwable) {
                // Some firmware exposes a second alignment arg.
                printerClass.getMethod(
                    "printBitmap",
                    Bitmap::class.java,
                    Int::class.javaPrimitiveType
                ).invoke(printer, toPrint, 0)
            }

            try {
                printerClass.getMethod("step", Int::class.javaPrimitiveType).invoke(printer, 100)
            } catch (_: Throwable) {}

            val started = tryInvokeAny(printer, listOf("start", "startPrint", "printStart"))
            if (!started) {
                throw IllegalStateException("Printer start method not found on ${printerClass.name}")
            }
        } catch (e: ClassNotFoundException) {
            throw IllegalStateException(
                "PAX Neptune SDK not found. Put NeptuneLite .aar/.jar in android/app/libs and rebuild app.",
                e
            )
        } catch (e: Throwable) {
            val root = e.cause
            val details = if (root != null) {
                "${e.message} | cause=${root.javaClass.simpleName}:${root.message}"
            } else {
                e.message
            }
            throw IllegalStateException("PAX printer error: $details", e)
        } finally {
            if (!toPrint.isRecycled) {
                toPrint.recycle()
            }
        }
    }

    private fun resolveDalWithFallback(neptuneClass: Class<*>, neptune: Any): Any {
        val attempts = StringBuilder()
        try {
            return neptuneClass
                .getMethod("getDalWithProcessSafe", android.content.Context::class.java)
                .invoke(neptune, this)
        } catch (e: Throwable) {
            attempts.append("getDalWithProcessSafe(activity): ${e.message}; ")
        }
        try {
            return neptuneClass
                .getMethod("getDal", android.content.Context::class.java)
                .invoke(neptune, applicationContext)
        } catch (e: Throwable) {
            attempts.append("getDal(applicationContext): ${e.message}; ")
        }
        try {
            return neptuneClass
                .getMethod("getDal", android.content.Context::class.java)
                .invoke(neptune, this)
        } catch (e: Throwable) {
            attempts.append("getDal(activity): ${e.message}; ")
        }
        // Some ROM variants expose no-arg getDal() only; use reflection fallback.
        try {
            val m = neptuneClass.getMethod("getDal")
            val dal = m.invoke(neptune)
            if (dal != null) return dal
            attempts.append("getDal() returned null; ")
        } catch (e: Throwable) {
            attempts.append("getDal() reflection failed: ${e.message}; ")
        }
        throw IllegalStateException("LOAD DAL ERR. $attempts")
    }

    private fun buildTestBitmap(customText: String?): Bitmap {
        val width = 384
        val height = 220
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.WHITE)

        val title = Paint().apply {
            color = Color.BLACK
            textSize = 34f
            isFakeBoldText = true
        }
        val body = Paint().apply {
            color = Color.BLACK
            textSize = 24f
        }
        val header = customText?.lineSequence()?.firstOrNull()?.take(28) ?: "POSEASE TEST PRINT"
        canvas.drawText(header, 20f, 60f, title)
        canvas.drawText("PAX terminal printer check", 20f, 110f, body)
        canvas.drawText(java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(java.util.Date()), 20f, 150f, body)
        canvas.drawText("OK", 20f, 190f, body)
        return bmp
    }

    private fun tryInvokeAny(target: Any, methodNames: List<String>): Boolean {
        for (name in methodNames) {
            try {
                target.javaClass.getMethod(name).invoke(target)
                return true
            } catch (_: Throwable) {}
        }
        return false
    }
}
