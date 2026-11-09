package pro.netro.netro

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import libXray.LibXray
import org.json.JSONObject

/** Общее состояние ядра для Activity и VPN-сервиса (один процесс). */
object XrayCore {
    @Volatile var state: String = "off"
        private set

    private val main = Handler(Looper.getMainLooper())
    var sink: EventChannel.EventSink? = null

    fun setState(s: String) {
        state = s
        main.post { sink?.success(s) }
    }

    /** Вызов libXray: возвращает JSON-ответ как строку. */
    fun invoke(method: String, payload: JSONObject): JSONObject {
        val req = JSONObject()
            .put("apiVersion", 3)
            .put("method", method)
            .put("payload", payload)
        return JSONObject(LibXray.invoke(req.toString()))
    }

    fun invokeRaw(request: String): String = LibXray.invoke(request)
}
