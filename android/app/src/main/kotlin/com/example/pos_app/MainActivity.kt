package com.example.pos_app

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Base64
import org.json.JSONObject
import java.lang.ClassNotFoundException
import java.lang.IllegalStateException
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.example.pos_app"
    private val uniPosPackage = "mn.genesis.unipos.terminal"
    private val uniPosRequestCode = 9301
    private var pendingUniPosResult: MethodChannel.Result? = null

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
                            val bitmap = buildTestBitmap()
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
                            launchUniPos(requestJson.toString(), result)
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
                            launchUniPos(requestJson.toString(), result)
                        } catch (e: Throwable) {
                            result.error("UNIPOS_ERROR", e.message, null)
                        }
                    }
                    "android.unipos.settlement" -> {
                        val requestJson = JSONObject().apply {
                            put("command", "SETTLEMENT")
                        }
                        launchUniPos(requestJson.toString(), result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchUniPos(request: String, result: MethodChannel.Result) {
        if (pendingUniPosResult != null) {
            result.error("BUSY", "UniPOS request already in progress", null)
            return
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, request)
            setPackage(uniPosPackage)
        }
        val canResolve = intent.resolveActivity(packageManager) != null
        if (!canResolve) {
            result.error("UNIPOS_NOT_FOUND", "UniPOS app is not installed", null)
            return
        }
        pendingUniPosResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, uniPosRequestCode)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != uniPosRequestCode) return

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
    }

    private fun decodeBase64ToBitmap(base64Data: String): Bitmap? {
        val bytes = Base64.decode(base64Data, Base64.DEFAULT)
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun printBitmapOnPax(bitmap: Bitmap) {
        try {
            val neptuneClass = Class.forName("com.pax.neptunelite.api.NeptuneLiteUser")
            val neptune = resolveNeptuneInstance(neptuneClass)
            val dal = resolveDal(neptuneClass, neptune, this)

            val dalClass = dal.javaClass
            val getPrinter = dalClass.getMethod("getPrinter")
            val printer = getPrinter.invoke(dal)
                ?: throw IllegalStateException("DAL returned null printer instance")

            val printerClass = printer.javaClass
            try {
                printerClass.getMethod("init").invoke(printer)
            } catch (_: Throwable) {}

            try {
                printerClass.getMethod("printBitmap", Bitmap::class.java).invoke(printer, bitmap)
            } catch (_: Throwable) {
                // Some firmware exposes a second alignment arg.
                printerClass.getMethod(
                    "printBitmap",
                    Bitmap::class.java,
                    Int::class.javaPrimitiveType
                ).invoke(printer, bitmap, 0)
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
        }
    }

    private fun resolveNeptuneInstance(neptuneClass: Class<*>): Any {
        // NeptuneLite API v3.x: static getInstance() only. Some device ROMs may ship a different
        // implementation; exceptions were previously swallowed and misreported as "returned null".
        val details = StringBuilder()
        try {
            val inst = neptuneClass.getMethod("getInstance").invoke(null)
            if (inst != null) return inst
            details.append("getInstance() returned null. ")
        } catch (e: Throwable) {
            details.append(
                "getInstance() failed: ${e.javaClass.simpleName}: ${e.message ?: "no message"}. "
            )
        }
        try {
            val m = neptuneClass.getMethod("getInstance", android.content.Context::class.java)
            val inst = m.invoke(null, this)
            if (inst != null) return inst
            details.append("getInstance(Activity) returned null. ")
        } catch (e: Throwable) {
            details.append(
                "getInstance(Context) unavailable or failed: ${e.javaClass.simpleName}: ${e.message ?: "no message"}. "
            )
        }
        throw IllegalStateException(
            "Unable to obtain NeptuneLiteUser. $details " +
                "Install/run on a PAX PayDroid terminal with Neptune service; emulators and normal phones will not work."
        )
    }

    private fun resolveDal(neptuneClass: Class<*>, neptune: Any, context: android.content.Context): Any {
        // Prefer process-safe DAL load (matches pax_sdk / multi-process Flutter engine behavior).
        val processSafe = try {
            neptuneClass
                .getMethod("getDalWithProcessSafe", android.content.Context::class.java)
                .invoke(neptune, context)
        } catch (_: Throwable) {
            null
        }
        if (processSafe != null) return processSafe

        val withContext = try {
            neptuneClass
                .getMethod("getDal", android.content.Context::class.java)
                .invoke(neptune, context)
        } catch (_: Throwable) {
            null
        }
        if (withContext != null) return withContext

        val noArg = try {
            neptuneClass.getMethod("getDal").invoke(neptune)
        } catch (_: Throwable) {
            null
        }
        if (noArg != null) return noArg

        throw IllegalStateException("Unable to resolve DAL from Neptune instance (try getDalWithProcessSafe/getDal)")
    }

    private fun buildTestBitmap(): Bitmap {
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
        canvas.drawText("POSEASE TEST PRINT", 20f, 60f, title)
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
