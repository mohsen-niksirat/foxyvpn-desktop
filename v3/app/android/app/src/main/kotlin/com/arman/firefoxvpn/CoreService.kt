package com.arman.firefoxvpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import java.io.File
import java.util.Locale

/**
 * The Go core (core/mobile, built into libs/core.aar by gomobile) runs in
 * this process. While the UI is open it runs with the proxy off, so the
 * settings and the accounts work. Turned on (the app's button, the Quick
 * Settings tile), this service keeps the core running in the foreground.
 * In VPN mode it is also the phone's VPN: it hands the core the VPN's TUN
 * device, so every app's TCP traffic goes through the proxy; the app
 * itself is left out of the VPN, so the core's own connections go straight
 * out. In proxy mode there is no VPN: only apps set up to use the local
 * proxy (127.0.0.1 and the proxy port) go through it. The notification's
 * Stop action turns it off.
 */
class CoreService : VpnService() {
    private val main = Handler(Looper.getMainLooper())

    /** The country the notification shows; "" for "Connecting…", NO_NETWORK for none. */
    private var shownCountry: String? = null

    /** The local proxy the notification names (proxy mode); "" for none. */
    private var shownProxy = ""

    /** The speed the notification shows (the user's choice); "" for none. */
    private var shownSpeed = ""

    /** Android reported that no network is connected (no Wi-Fi, no mobile data). */
    @Volatile
    private var offline = false

    /** onDestroy ran: a network callback still in flight must not post again. */
    @Volatile
    private var destroyed = false

    /**
     * Keeps the notification on the country the traffic leaves from, and,
     * once the routing region's list arrives for a user who has not chosen
     * apps yet, checks the suggested apps and sets the interface up again.
     */
    private val watchCountry = object : Runnable {
        override fun run() {
            if (destroyed) return
            if (on && !mobile.Mobile.running()) {
                Log.e(TAG, "the core stopped; turning the VPN off")
                turnOff(this@CoreService)
                return
            }
            // The core gave the connect up (no connection to Mozilla within
            // a minute): the VPN and its notification go too.
            if (on && !mobile.Mobile.isOn()) {
                Log.w(TAG, "the connect was given up; turning the VPN off")
                turnOff(this@CoreService)
                return
            }
            val code = when {
                offline -> NO_NETWORK
                mobile.Mobile.running() -> mobile.Mobile.exitCountry()
                else -> ""
            }
            connected = on && code.length == 2
            ConnectWidget.updateAll(this@CoreService)
            // Proxy mode names the address apps connect to; the VPN needs none.
            val proxy = if (usesVpn(this@CoreService) || !mobile.Mobile.running()) "" else mobile.Mobile.proxyAddress()
            val speed = if (showSpeed(this@CoreService) && !offline && mobile.Mobile.running()) speedText(mobile.Mobile.speed()) else ""
            if (code != shownCountry || proxy != shownProxy || speed != shownSpeed) {
                shownCountry = code
                shownProxy = proxy
                shownSpeed = speed
                getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(code))
            }
            if (on && usesVpn(this@CoreService) && appMode(this@CoreService) == MODE_EXCLUDE && suggestOnce(this@CoreService)) {
                if (!startTunnel()) turnOff(this@CoreService)
            }
            // The speed changes all the time: shown, it is read more often.
            main.postDelayed(this, if (showSpeed(this@CoreService)) SPEED_POLL_MS else COUNTRY_POLL_MS)
        }
    }

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    /**
     * Tells the core about the phone's network (apps may not read the route
     * table): lost, and back or another one, so the core reconnects to
     * Mozilla at once, and the app and the notification say at once when
     * there is none. The VPN follows it as its underlying network.
     *
     * The network watched is the best one that is not a VPN. This app's own
     * default network is no good for that on Android 12 and later: it can be
     * this VPN, whatever the app list says, and then a switch from Wi-Fi to
     * mobile data reached no one, the VPN stayed on the Wi-Fi that was gone,
     * and apps said "Waiting for network".
     */
    private fun watchNetwork() {
        if (networkCallback != null) return
        val callback = object : ConnectivityManager.NetworkCallback() {
            private var current: Network? = null
            private var lost = false

            override fun onAvailable(network: Network) {
                // This VPN's own network is no underlying one.
                val caps = getSystemService(ConnectivityManager::class.java).getNetworkCapabilities(network)
                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) return
                // A "no network" report from an earlier run of the VPN is
                // taken back too, or the core would wait for a network.
                val changed = (current != null && current != network) || (current == null && lost) || reportedDown
                current = network
                lost = false
                setUnderlyingNetworks(arrayOf(network))
                if (changed) {
                    mobile.Mobile.networkChanged(true)
                    reportedDown = false
                }
                if (offline) {
                    offline = false
                    refreshNotification()
                }
            }

            override fun onLost(network: Network) {
                if (network != current) return // another one took over already
                current = null
                lost = true
                setUnderlyingNetworks(null)
                mobile.Mobile.networkChanged(false)
                reportedDown = true
                offline = true
                refreshNotification()
            }
        }
        try {
            val connectivity = getSystemService(ConnectivityManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    .build()
                connectivity.registerBestMatchingNetworkCallback(request, callback, main)
            } else {
                connectivity.registerDefaultNetworkCallback(callback)
            }
            networkCallback = callback
            // With no network at all the callback reports nothing: say so now.
            if (!hasNetwork(connectivity)) {
                mobile.Mobile.networkChanged(false)
                reportedDown = true
                offline = true
                refreshNotification()
            }
        } catch (e: Exception) {
            Log.w(TAG, "watching the network failed", e)
        }
    }

    /** Whether a network other than a VPN can reach the internet. */
    @Suppress("DEPRECATION") // allNetworks: the one way to list them all
    private fun hasNetwork(connectivity: ConnectivityManager): Boolean =
        connectivity.allNetworks.any { network ->
            val caps = connectivity.getNetworkCapabilities(network)
            caps != null &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                !caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        }

    /** Shows the network state in the notification now, not at the next poll. */
    private fun refreshNotification() {
        if (destroyed) return
        main.removeCallbacks(watchCountry)
        main.post(watchCountry)
    }

    private fun stopWatchingNetwork() {
        val callback = networkCallback ?: return
        networkCallback = null
        try {
            getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            // Not registered.
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            turnOff(this)
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_RECONNECT) {
            // New settings: the apps left out of the VPN, or the mode.
            if (on) {
                if (usesVpn(this)) {
                    if (!startTunnel()) turnOff(this)
                } else {
                    mobile.Mobile.stopTun()
                }
            }
            return START_STICKY
        }
        startInForeground()
        // Started by turnOn, or again by the system after it ended the
        // process: either way the VPN is on.
        startCore(this, on = true)
        // On already after the button (Connect, which a SetOn would cancel);
        // this turns it on after the system restarted the service.
        if (!mobile.Mobile.isOn()) mobile.Mobile.setOn(true)
        if (usesVpn(this) && !startTunnel()) {
            turnOff(this)
            return START_NOT_STICKY
        }
        on = true
        offline = reportedDown
        QuickTile.refresh(this)
        ConnectWidget.updateAll(this)
        main.removeCallbacks(watchCountry)
        main.post(watchCountry)
        watchNetwork()
        return START_STICKY
    }

    /** Another VPN took over, or the user ended this one in the settings. */
    override fun onRevoke() {
        turnOff(this)
    }

    override fun onDestroy() {
        destroyed = true
        main.removeCallbacks(watchCountry)
        stopWatchingNetwork()
        mobile.Mobile.stopTun()
        on = false
        connected = false
        QuickTile.refresh(this)
        ConnectWidget.updateAll(this)
        super.onDestroy()
    }

    /** Sets up the VPN interface and gives its device to the core. */
    private fun startTunnel(): Boolean {
        if (prepare(this) != null) {
            // No permission (revoked since): the app asks again.
            Log.w(TAG, "the VPN has no permission")
            return false
        }
        return try {
            val builder = Builder()
                .setSession(getString(R.string.app_name))
                .setMtu(MTU)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                // The core answers DNS sent to any address.
                .addDnsServer("172.19.0.2")
                .addAddress("fdfe:dcba:9876::1", 126)
                .addRoute("::", 0)
            applyApps(builder)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)
            val tun = builder.establish() ?: return false
            mobile.Mobile.startTun(tun.detachFd())
            true
        } catch (e: Exception) {
            Log.e(TAG, "the VPN did not start", e)
            Toast.makeText(this, e.message ?: e.toString(), Toast.LENGTH_LONG).show()
            false
        }
    }

    /**
     * Which apps use the VPN (Routing in the settings): only the chosen
     * ones (Proxy selected apps), or all but this app and the chosen ones
     * (Bypass selected apps). Apps no longer installed are skipped.
     */
    private fun applyApps(builder: Builder) {
        fun each(packages: Set<String>, add: (String) -> Unit) {
            for (pkg in packages) {
                try {
                    add(pkg)
                } catch (e: PackageManager.NameNotFoundException) {
                    // Uninstalled since.
                }
            }
        }
        // Only the chosen apps that are still installed: with none, the
        // allow list would be empty, and Android would send every app, this
        // one included, into the VPN (a loop). Then it is as if none were
        // chosen. The Builder keeps what was added, so the count decides.
        if (appMode(this) == MODE_INCLUDE) {
            var added = 0
            each(appSet(this, ONLY) - packageName) {
                builder.addAllowedApplication(it)
                added++
            }
            if (added > 0) return
        }
        builder.addDisallowedApplication(packageName)
        suggestOnce(this)
        each(appSet(this, BYPASS) - packageName) { builder.addDisallowedApplication(it) }
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // No badge on the app icon: the notification is a state, not a
            // message (Samsung showed a "1"). A channel's badge setting is
            // fixed once created, so the old channel gives way to a new one.
            manager.deleteNotificationChannel(OLD_CHANNEL)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, getString(R.string.notification_channel), NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) },
            )
        }
        shownCountry = ""
        shownProxy = ""
        shownSpeed = ""
        val notification = notification("")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * The VPN's notification: the flag and name (in the phone's language) of
     * the country [code] the traffic leaves from, or "Connecting…" while it
     * is unknown; a Stop action.
     */
    private fun notification(code: String): Notification {
        val state = when {
            code == NO_NETWORK -> getString(R.string.notification_no_network)
            code.length == 2 -> "${flag(code)}  ${Locale.Builder().setRegion(code).build().displayCountry}"
            else -> getString(R.string.notification_connecting)
        }
        // The speed beside the place, on the line shown when collapsed; the
        // proxy address (proxy mode) also while connecting, so the user sees
        // it is the proxy, not the VPN.
        val first = if (shownSpeed.isEmpty()) state else "$state  ·  $shownSpeed"
        val text = if (shownProxy.isEmpty()) first else "$first\n${getString(R.string.notification_proxy, shownProxy)}"
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, CoreService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_logo)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, getString(R.string.notification_stop), stop).build())
            .build()
    }

    companion object {
        const val ACTION_STOP = "com.arman.firefoxvpn.STOP"
        private const val ACTION_RECONNECT = "com.arman.firefoxvpn.RECONNECT"
        private const val PREFS = "vpn"
        private const val MODE = "app_mode"
        const val MODE_EXCLUDE = "exclude"
        const val MODE_INCLUDE = "include"

        private const val CONNECTION = "connection_mode"

        /** The whole phone goes through the VPN. */
        const val MODE_VPN = "vpn"

        /** No VPN: only apps set up to use the local proxy. */
        const val MODE_PROXY = "proxy"

        private const val NO_NETWORK = "-"

        private const val SHOW_SPEED = "show_speed"

        /** Whether the notification shows the speed (off unless chosen). */
        fun showSpeed(context: Context) = prefs(context).getBoolean(SHOW_SPEED, false)

        fun setShowSpeed(context: Context, on: Boolean) {
            prefs(context).edit().putBoolean(SHOW_SPEED, on).apply()
        }

        /** "↓ 1.2 MB/s  ↑ 35 KB/s" from the core's "down,up" in bytes per second. */
        fun speedText(downUp: String): String {
            val parts = downUp.split(",")
            val down = parts.getOrNull(0)?.toLongOrNull() ?: 0
            val up = parts.getOrNull(1)?.toLongOrNull() ?: 0
            return "↓ ${rate(down)}  ↑ ${rate(up)}"
        }

        private fun rate(bytes: Long): String = when {
            bytes >= 1024 * 1024 -> String.format(Locale.US, "%.1f MB/s", bytes / 1048576.0)
            bytes >= 1024 -> "${bytes / 1024} KB/s"
            else -> "$bytes B/s"
        }

        fun connectionMode(context: Context): String =
            prefs(context).getString(CONNECTION, MODE_VPN) ?: MODE_VPN

        fun usesVpn(context: Context) = connectionMode(context) != MODE_PROXY

        /** Keeps the mode; a running service switches to it at once. */
        fun setConnectionMode(context: Context, mode: String) {
            prefs(context).edit().putString(CONNECTION, if (mode == MODE_PROXY) MODE_PROXY else MODE_VPN).apply()
            reconnect(context)
        }

        /** Apps left out of the VPN, by the user. */
        const val BYPASS = "bypass_apps"

        /** In MODE_INCLUDE, the only apps that use the VPN. */
        const val ONLY = "only_apps"

        private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun appMode(context: Context): String = prefs(context).getString(MODE, MODE_EXCLUDE) ?: MODE_EXCLUDE

        fun appSet(context: Context, key: String): Set<String> = prefs(context).getStringSet(key, emptySet()) ?: emptySet()

        /** Keeps the app choice: the mode and the three sets. */
        fun setAppRouting(context: Context, mode: String, sets: Map<String, Set<String>>) {
            val edit = prefs(context).edit().putString(MODE, mode)
            for ((key, packages) in sets) edit.putStringSet(key, packages)
            edit.apply()
        }

        /**
         * Until the user first chooses, the routing region's suggested apps
         * (core/routing) start out checked; afterwards only the user's
         * choice counts, and the app's "Suggested apps" adds them again.
         * Reports whether it checked them now.
         */
        fun suggestOnce(context: Context): Boolean {
            if (prefs(context).contains(BYPASS)) return false
            val suggested = regionAppList().toSet()
            if (suggested.isEmpty()) return false
            prefs(context).edit().putStringSet(BYPASS, suggested).apply()
            return true
        }

        /** The routing region's suggested apps (core/routing). */
        fun regionAppList(): List<String> =
            if (mobile.Mobile.running()) mobile.Mobile.directApps().lines().filter { it.isNotBlank() } else emptyList()

        /** Sets the VPN interface up again, if on, with the current settings. */
        fun reconnect(context: Context) {
            if (!on) return
            context.startService(Intent(context, CoreService::class.java).setAction(ACTION_RECONNECT))
        }
        private const val CHANNEL = "status"
        private const val OLD_CHANNEL = "core"
        private const val NOTIFICATION_ID = 1
        private const val TAG = "CoreService"

        private const val COUNTRY_POLL_MS = 3000L
        private const val SPEED_POLL_MS = 2000L

        /** A country's flag emoji: its code in regional indicator letters. */
        fun flag(code: String): String =
            code.uppercase().filter { it in 'A'..'Z' }
                .map { String(Character.toChars(0x1F1E6 + (it - 'A'))) }
                .joinToString("")

        /** The VPN interface's MTU; the core's stack uses the same. */
        private const val MTU = 1500

        /** The core was last told that no network is connected. */
        @Volatile
        private var reportedDown = false

        /** The VPN is on: the service runs. */
        @Volatile
        var on = false
            private set

        /**
         * On and through: the exit country is known (the notification shows
         * it). On but not [connected] is "Connecting…", for the widget.
         */
        @Volatile
        var connected = false
            private set

        /** The core's data folder: accounts, settings, logs, the local token. */
        fun dataDir(context: Context): File = File(context.filesDir, "core")

        /**
         * Turns the proxy on, and in VPN mode the VPN. For the VPN the user
         * must have given the permission ([VpnService.prepare] returns
         * null). It throws when Android does
         * not let the service start now (from the background on Android 12
         * and later).
         */
        fun turnOn(context: Context) {
            val intent = Intent(context, CoreService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            startCore(context, on = true)
            // Given up by the core if it does not reach Mozilla in a minute.
            mobile.Mobile.connect()
            on = true
            connected = false
            QuickTile.refresh(context)
            ConnectWidget.updateAll(context)
        }

        /** Turns the VPN and the proxy off; the core keeps its API. */
        fun turnOff(context: Context) {
            if (mobile.Mobile.running()) {
                mobile.Mobile.stopTun()
                mobile.Mobile.setOn(false)
            }
            on = false
            connected = false
            context.stopService(Intent(context, CoreService::class.java))
            QuickTile.refresh(context)
            ConnectWidget.updateAll(context)
        }

        /** Starts the core, with the proxy [on] or off, if it does not run. */
        @Synchronized
        fun startCore(context: Context, on: Boolean) {
            if (mobile.Mobile.running()) return
            if ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
                importFromComputer(context)
            } else {
                // Shared storage is writable by other apps on older Android:
                // a release build never takes data from there.
                File(context.getExternalFilesDir(null), "import").takeIf { it.exists() }?.deleteRecursively()
            }
            try {
                mobile.Mobile.start(dataDir(context).absolutePath, on)
            } catch (e: Exception) {
                Log.e(TAG, "the core did not start", e)
            }
        }

        /**
         * Takes a data folder copied from the computer (adb push to the
         * app's external files dir, `import/`): the accounts and the core's
         * settings, so the phone needs no new sign-in. A development aid in
         * debug builds only, until the app has its own export and import;
         * the copy is deleted.
         */
        private fun importFromComputer(context: Context) {
            val source = File(context.getExternalFilesDir(null), "import")
            if (!source.isDirectory) return
            val target = dataDir(context).apply { mkdirs() }
            try {
                for (name in listOf("config.json", "state.json", "selection.json")) {
                    val file = File(source, name)
                    if (file.isFile) file.copyTo(File(target, name), overwrite = true)
                }
                File(source, "accounts").takeIf { it.isDirectory }
                    ?.copyRecursively(File(target, "accounts"), overwrite = true)
                Log.i(TAG, "imported the data copied from the computer")
            } catch (e: Exception) {
                Log.e(TAG, "the import failed", e)
            } finally {
                source.deleteRecursively()
            }
        }

        @Synchronized
        fun stopCore() {
            if (mobile.Mobile.running()) mobile.Mobile.stop()
        }
    }
}
