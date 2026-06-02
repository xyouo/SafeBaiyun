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
import cn.huacheng.safebaiyun.util.UpdateChecker
import cn.huacheng.safebaiyun.util.UpdateInfo

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SafeBaiyunTheme {
                var updateInfo by remember { mutableStateOf<UpdateInfo?>(null) }
                val context = LocalContext.current

                LaunchedEffect(Unit) {
                    updateInfo = UpdateChecker.checkForUpdate(BuildConfig.VERSION_NAME)
                }

                updateInfo?.let { info ->
                    if (info.hasUpdate) {
                        AlertDialog(
                            onDismissRequest = { updateInfo = null },
                            title = { Text("鍙戠幇鏂扮増鏈?) },
                            text = { Text("鏂扮増鏈?${info.latestVersion} 宸插彂甯冿紝鏄惁绔嬪嵆鏇存柊锛?) },
                            confirmButton = {
                                TextButton(onClick = {
                                    val url = if (info.downloadUrl.isNotEmpty()) info.downloadUrl else "https://github.com/xyouo/SafeBaiyun/releases/latest"
                                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                                    updateInfo = null
                                }) { Text("鏇存柊") }
                            },
                            dismissButton = {
                                TextButton(onClick = { updateInfo = null }) { Text("绋嶅悗") }
                            }
                        )
                    }
                }

                val navController = rememberNavController()
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
            }
        }
    }
}