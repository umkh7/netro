package pro.netro.netro

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private var pending: Pair<String, String>? = null
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_VPN = 4711
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "netro/state").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                XrayCore.sink = events
                events.success(XrayCore.state)
            }

            override fun onCancel(arguments: Any?) {
                XrayCore.sink = null
            }
        })

        MethodChannel(messenger, "netro/core").setMethodCallHandler { call, result ->
            when (call.method) {
                "invoke" -> {
                    val req = call.arguments as String
                    io.execute {
                        val out = try {
                            XrayCore.invokeRaw(req)
                        } catch (e: Throwable) {
                            "{\"success\":false,\"error\":\"${e.message?.replace("\"", "'")}\"}"
                        }
                        main.post { result.success(out) }
                    }
                }
                "start" -> {
                    val cfg = call.argument<String>("config") ?: return@setMethodCallHandler result.error("arg", "config", null)
                    val mode = call.argument<String>("mode") ?: "tun"
                    askNotificationsOnce()
                    if (mode == "tun") {
                        val prep = VpnService.prepare(this)
                        if (prep != null) {
                            pending = cfg to mode
                            pendingResult = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(prep, REQ_VPN)
                            return@setMethodCallHandler
                        }
                    }
                    NetroVpnService.start(this, cfg, mode)
                    result.success(null)
                }
                "stop" -> {
                    NetroVpnService.stop(this)
                    result.success(null)
                }
                "state" -> result.success(XrayCore.state)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_VPN) return
        val p = pending
        val r = pendingResult
        pending = null
        pendingResult = null
        if (resultCode == RESULT_OK && p != null) {
            NetroVpnService.start(this, p.first, p.second)
            r?.success(null)
        } else {
            XrayCore.setState("off")
            r?.error("denied", "Разрешение на VPN не выдано", null)
        }
    }

    private var askedNotif = false
    private fun askNotificationsOnce() {
        if (askedNotif || Build.VERSION.SDK_INT < 33) return
        askedNotif = true
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}
