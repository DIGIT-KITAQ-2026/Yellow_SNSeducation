package com.yellow.yellow_sns_education

import android.app.AppOpsManager
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
        fun isUserFacing(packageName: String): Boolean {
            return userFacingCache.getOrPut(packageName) {
                packageName !in homePackages &&
                    pm.getLaunchIntentForPackage(packageName) != null
            }
        }

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
}
