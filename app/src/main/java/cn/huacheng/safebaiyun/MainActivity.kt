package cn.huacheng.safebaiyun

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.slideIn
import androidx.compose.animation.slideOut
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntOffset
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import cn.huacheng.safebaiyun.compose.HelpView
import cn.huacheng.safebaiyun.compose.MainView
import cn.huacheng.safebaiyun.theme.SafeBaiyunTheme
import cn.huacheng.safebaiyun.util.AppSettings
import cn.huacheng.safebaiyun.util.UpdateChecker

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SafeBaiyunTheme {
                var updateInfo by remember { mutableStateOf<cn.huacheng.safebaiyun.util.UpdateInfo?>(null) }
                val context = LocalContext.current
                val navController = rememberNavController()

                if (AppSettings.autoCheckUpdate) {
                    LaunchedEffect(Unit) {
                        updateInfo = UpdateChecker.checkForUpdate(BuildConfig.VERSION_NAME)
                    }
                }

                Surface(
                    modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background
                ) {
                    NavHost(navController = navController, startDestination = "main") {
                        composable("main", enterTransition = { slideIn { IntOffset(-it.width, 0) } }, exitTransition = { slideOut { IntOffset(-it.width, 0) } }) {
                            MainView(navController)
                        }
                        composable("helper", enterTransition = { slideIn { IntOffset(it.width, 0) } }, exitTransition = { slideOut { IntOffset(it.width, 0) } }) {
                            HelpView(navController)
                        }
                    }
                }

                if (updateInfo?.hasUpdate == true) {
                    val info = updateInfo!!
                    AlertDialog(
                        onDismissRequest = { updateInfo = null },
                        title = { Text("发现新版本") },
                        text = { Text("新版本 " + info.latestVersion + " 已发布，是否立即更新？") },
                        confirmButton = {
                            TextButton(onClick = {
                                val url = if (info.downloadUrl.isNotEmpty()) info.downloadUrl else "https://github.com/xyouo/SafeBaiyun/releases/latest"
                                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                updateInfo = null
                            }) { Text("更新") }
                        },
                        dismissButton = {
                            TextButton(onClick = { updateInfo = null }) { Text("稍后") }
                        }
                    )
                }
            }
        }
    }
}