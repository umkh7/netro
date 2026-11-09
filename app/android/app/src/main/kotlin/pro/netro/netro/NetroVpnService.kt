package pro.netro.netro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import libXray.DialerController
import libXray.LibXray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * VPN-сервис Netro. Режим «tun»: весь трафик телефона идёт в TUN, который читает Xray.
 * Режим «proxy»: только локальные SOCKS5/HTTP на 127.0.0.1 (без VPN).
 */
data class VpnOpts(val dns: String = "1.1.1.1", val split: String = "off", val apps: List<String> = emptyList())

class NetroVpnService : VpnService() {

    companion object {
        const val ACTION_START = "pro.netro.START"
        const val ACTION_STOP = "pro.netro.STOP"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_MODE = "mode"
        private const val CHANNEL = "netro_vpn"
        private const val NOTIF_ID = 7
        private const val TAG = "Netro"
        @Volatile var opts = VpnOpts()

        fun start(ctx: Context, config: String, mode: String) {
            val i = Intent(ctx, NetroVpnService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_CONFIG, config)
                .putExtra(EXTRA_MODE, mode)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.startService(Intent(ctx, NetroVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    private val worker = Executors.newSingleThreadExecutor()
    private var tun: ParcelFileDescriptor? = null
    @Volatile private var running = false

    private val protector = object : DialerController {
        override fun protectFd(fd: Long): Boolean = protect(fd.toInt())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                worker.execute { stopCore() }
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val cfg = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                val mode = intent.getStringExtra(EXTRA_MODE) ?: "tun"
                startForegroundCompat()
                worker.execute {
                    if (running) stopCore(keepService = true)
                    startCore(cfg, mode)
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun startCore(configJson: String, mode: String) {
        XrayCore.setState("connecting")
        try {
            val cfg = JSONObject(configJson)
            if (mode == "tun") {
                val b = Builder()
                    .setSession("Netro")
                    .setMtu(1500)
                    .addAddress("172.19.0.1", 30)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer(opts.dns)
                try {
                    b.addAddress("fdfe:dcba:9876::1", 126)
                    b.addRoute("::", 0)
                } catch (_: Exception) {
                }
                // Раздельное туннелирование. Само приложение всегда мимо VPN — чтобы ядро не зацикливалось.
                when (opts.split) {
                    "include" -> opts.apps.forEach { p -> try { b.addAllowedApplication(p) } catch (_: Exception) {} }
                    else -> {
                        try { b.addDisallowedApplication(packageName) } catch (_: Exception) {}
                        if (opts.split == "exclude") {
                            opts.apps.forEach { p -> try { b.addDisallowedApplication(p) } catch (_: Exception) {} }
                        }
                    }
                }
                if (Build.VERSION.SDK_INT >= 29) b.setMetered(false)
                val pfd = b.establish() ?: throw IllegalStateException("Нет разрешения на VPN")
                tun = pfd
                val env = cfg.optJSONObject("env") ?: JSONObject()
                env.put("xray.tun.fd", pfd.fd.toString())
                cfg.put("env", env)
            }
            LibXray.registerDialerController(protector)
            try { LibXray.setDNS(protector, "${opts.dns}:53") } catch (e: Exception) { Log.w(TAG, "setDNS: $e") }
            val res = XrayCore.invoke("runXray", JSONObject().put("xrayJson", cfg.toString()))
            if (!res.optBoolean("success")) {
                throw IllegalStateException(res.optString("error", "Ядро не запустилось"))
            }
            running = true
            updateNotification(if (mode == "tun") "VPN включён" else "Прокси 127.0.0.1:10808 включён")
            XrayCore.setState("on")
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            XrayCore.setState("error")
            stopCore()
        }
    }

    private fun stopCore(keepService: Boolean = false) {
        try {
            if (running) XrayCore.invoke("stopXray", JSONObject())
        } catch (e: Exception) {
            Log.w(TAG, "stop: $e")
        }
        running = false
        try { LibXray.resetDNS() } catch (_: Exception) {}
        try { tun?.close() } catch (_: Exception) {}
        tun = null
        if (!keepService) {
            XrayCore.setState("off")
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
            stopSelf()
        }
    }

    override fun onRevoke() {
        // Пользователь включил другой VPN или отозвал разрешение.
        worker.execute { stopCore() }
    }

    override fun onDestroy() {
        if (running) stopCore()
        super.onDestroy()
    }

    private fun buildNotification(text: String): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Подключение", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, NetroVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setSmallIcon(R.drawable.ic_stat_netro)
            .setContentTitle("Netro")
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Отключить", stop).build())
            .build()
    }

    private fun startForegroundCompat() {
        val n = buildNotification("Подключение…")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java).notify(NOTIF_ID, buildNotification(text))
    }
}
