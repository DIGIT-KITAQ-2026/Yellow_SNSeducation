package com.yellow.yellow_sns_education

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android の UsageStatsManager をラップして、日毎・アプリ別の利用時間を返す
 * MethodChannel プラグイン。
 *
 * 「使用状況へのアクセス」は通常の実行時権限ではなく特別なアクセス権(App Ops)
 * であり、[Settings.ACTION_USAGE_ACCESS_SETTINGS] をユーザーが自分で開いて
 * 許可する必要がある。ここでは許可の有無を確認する [hasPermission] と、
 * 設定画面を開く [openSettings] を提供する。
 */
class ScreenTimePlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.yellow.yellow_sns_education/screen_time"
        private const val SELF_PACKAGE = "com.yellow.yellow_sns_education"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasUsagePermission())
            "openSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "queryDailyUsage" -> {
                val days = (call.argument<Int>("days")) ?: 7
                try {
                    result.success(queryDailyUsage(days))
                } catch (e: Exception) {
                    result.error("query_failed", e.message, null)
                }
            }
            "queryHourlyUsage" -> {
                val dateStr = call.argument<String>("date")
                try {
                    result.success(queryHourlyUsage(dateStr))
                } catch (e: Exception) {
                    result.error("query_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsagePermission(): Boolean {
        val ctx = context ?: return false
        val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                ctx.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                ctx.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val act = activity
        val ctx = context ?: return
        val packageName = ctx.packageName
        try {
            if (act != null) {
                act.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            } else {
                ctx.startActivity(
                    Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        } catch (e: Exception) {
            // 一部端末では汎用の設定一覧が開けないことがあるため、
            // 自アプリの詳細画面付き Intent にフォールバックする。
            val fallback = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .setData(Uri.parse("package:$packageName"))
            ctx.startActivity(fallback)
        }
    }

    /**
     * 直近[days]日分(今日を含む)を、新しい日付順(今日が先頭)で返す。
     * 各日は前日00:00〜当日00:00の [UsageStatsManager.INTERVAL_DAILY] 集計で、
     * 端末によって多少の丸め誤差がある。より厳密な按分が必要な場合は
     * queryEvents による ACTIVITY_RESUMED/PAUSED の突き合わせに置き換えること。
     *
     * 内訳は「ユーザーが自分で開くアプリ」だけに絞る。UsageStatsManager は
     * システムUI・IME・ホームアプリのような裏方のフォアグラウンド時間も返すため、
     * 絞らないと総利用時間が膨らみ、AI講評が「一番使っているアプリ」として
     * ランチャーを挙げてしまう。
     */
    private fun queryDailyUsage(days: Int): List<Map<String, Any?>> {
        val ctx = context ?: throw IllegalStateException("no context")
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = ctx.packageManager
        val tz = TimeZone.getDefault()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = tz }

        val labelCache = HashMap<String, String>()
        fun labelFor(packageName: String): String {
            return labelCache.getOrPut(packageName) {
                try {
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    packageName
                }
            }
        }

        val isUserFacing = buildIsUserFacingChecker(pm)

        val result = ArrayList<Map<String, Any?>>()
        val todayStart = Calendar.getInstance(tz).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        for (i in 0 until days) {
            val dayStart = (todayStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -i) }
            val dayEnd = (dayStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
            val from = dayStart.timeInMillis
            val to = dayEnd.timeInMillis

            val stats = usm.queryAndAggregateUsageStats(from, to)
            val apps = ArrayList<Map<String, Any?>>()
            for ((packageName, usageStats) in stats) {
                if (packageName == SELF_PACKAGE) continue
                if (!isUserFacing(packageName)) continue
                val minutes = (usageStats.totalTimeInForeground / 60000L).toInt()
                if (minutes < 1) continue
                apps.add(
                    mapOf(
                        "packageName" to packageName,
                        "label" to labelFor(packageName),
                        "minutes" to minutes,
                    )
                )
            }

            result.add(
                mapOf(
                    "date" to dateFormat.format(dayStart.time),
                    "apps" to apps,
                )
            )
        }

        return result
    }

    /**
     * [queryDailyUsage] と同じ「ユーザーが自分で開くアプリ」だけに絞る判定を、
     * [queryHourlyUsage] とも共有するためのファクトリ。ホームアプリの集合と
     * 判定結果はどちらもキャッシュして使い回す。
     */
    private fun buildIsUserFacingChecker(pm: PackageManager): (String) -> Boolean {
        // ホームアプリは CATEGORY_LAUNCHER ではなく CATEGORY_HOME で登録されている
        // ため getLaunchIntentForPackage では落ちない。個別に集めて除外する。
        val homePackages = pm
            .queryIntentActivities(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
                0,
            )
            .map { it.activityInfo.packageName }
            .toSet()

        val userFacingCache = HashMap<String, Boolean>()
        return { packageName ->
            userFacingCache.getOrPut(packageName) {
                packageName !in homePackages &&
                    pm.getLaunchIntentForPackage(packageName) != null
            }
        }
    }

    /**
     * [date](yyyy-MM-dd、未指定なら昨日)の1日分を、0〜23時の各時間帯における
     * 全アプリ合計の利用分数(0〜60)として24要素で返す。取得できたイベントが
     * 無ければ(端末のイベント保持期間切れ等)全て0の配列を返す。
     *
     * [queryDailyUsage] の [UsageStatsManager.queryAndAggregateUsageStats] は
     * 区間合計しか返さず時間帯に按分できないため、こちらは
     * [UsageStatsManager.queryEvents] で ACTIVITY_RESUMED/PAUSED
     * (MOVE_TO_FOREGROUND/BACKGROUND、値は同じ)を突き合わせて前景セッションの
     * 区間を作り、その区間を時間境界で切って各時間バケットに秒数を積む。
     */
    private fun queryHourlyUsage(date: String?): List<Int> {
        val ctx = context ?: throw IllegalStateException("no context")
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = ctx.packageManager
        val tz = TimeZone.getDefault()

        val dayStart = if (date != null) {
            val parsed = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = tz }.parse(date)
                ?: throw IllegalArgumentException("invalid date: $date")
            Calendar.getInstance(tz).apply {
                time = parsed
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        } else {
            Calendar.getInstance(tz).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, -1)
            }
        }
        val dayEnd = (dayStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
        val from = dayStart.timeInMillis
        val to = dayEnd.timeInMillis

        val isUserFacing = buildIsUserFacingChecker(pm)

        // 各アプリの「前景に入った時刻」。ACTIVITY_PAUSED が来たらセッションを
        // 確定してバケットに積み、除去する。範囲末尾まで前景のままだったアプリは
        // 最後に `to` で締める。
        val sessionStarts = HashMap<String, Long>()
        val bucketMillis = LongArray(24)

        fun closeSession(packageName: String, endMillis: Long) {
            val startMillis = sessionStarts.remove(packageName) ?: return
            addSessionToBuckets(startMillis.coerceAtLeast(from), endMillis.coerceAtMost(to), dayStart, bucketMillis)
        }

        val events = usm.queryEvents(from, to)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (packageName == SELF_PACKAGE) continue
            if (!isUserFacing(packageName)) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    sessionStarts[packageName] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND ->
                    closeSession(packageName, event.timeStamp)
            }
        }
        // まだ前景のまま範囲が終わったアプリは `to` で締める。
        for (packageName in sessionStarts.keys.toList()) {
            closeSession(packageName, to)
        }

        return bucketMillis.map { (it / 60000L).toInt().coerceIn(0, 60) }
    }

    /**
     * [startMillis, endMillis) の前景セッションを、属する時間バケット
     * (0〜23、[dayStart] からの経過時間で決まる)に按分して積む。
     */
    private fun addSessionToBuckets(
        startMillis: Long,
        endMillis: Long,
        dayStart: Calendar,
        bucketMillis: LongArray,
    ) {
        if (endMillis <= startMillis) return
        val dayStartMillis = dayStart.timeInMillis
        var cursor = startMillis
        while (cursor < endMillis) {
            val elapsed = cursor - dayStartMillis
            val hour = (elapsed / 3_600_000L).toInt().coerceIn(0, 23)
            val hourEnd = dayStartMillis + (hour + 1) * 3_600_000L
            val segmentEnd = minOf(endMillis, hourEnd)
            bucketMillis[hour] += segmentEnd - cursor
            cursor = segmentEnd
        }
    }
}
