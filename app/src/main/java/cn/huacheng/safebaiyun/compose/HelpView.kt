package cn.huacheng.safebaiyun.compose

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import cn.huacheng.safebaiyun.BuildConfig
import cn.huacheng.safebaiyun.util.AppSettings
import cn.huacheng.safebaiyun.util.UpdateChecker
import kotlinx.coroutines.launch

@Composable
fun HelpView(navController: NavController) {
    Column {
        HelperTopBar(navController)
        LazyColumn(modifier = Modifier.padding(12.dp)) {
            item { AppHelper() }
            item { UpdateSection() }
        }
    }
}

@Composable
private fun UpdateSection() {
    var autoCheck by remember { mutableStateOf(AppSettings.autoCheckUpdate) }
    var checking by remember { mutableStateOf(false) }
    var updateInfo by remember { mutableStateOf<cn.huacheng.safebaiyun.util.UpdateInfo?>(null) }
    var showUpdateDialog by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    Text("软件更新", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 8.dp))

    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text("启动时自动检查")
        Switch(checked = autoCheck, onCheckedChange = {
            autoCheck = it
            AppSettings.autoCheckUpdate = it
        })
    }

    Button(
        onClick = {
            checking = true
            scope.launch {
                val ver = try { BuildConfig.VERSION_NAME } catch (e: Exception) { "2.0" }
                val result = UpdateChecker.checkForUpdate(ver)
                updateInfo = result
                showUpdateDialog = result.hasUpdate
                checking = false
            }
        },
        enabled = !checking
    ) {
        Text(if (checking) "检查中..." else "检查更新")
    }

    if (!checking && updateInfo != null && !showUpdateDialog) {
        if (updateInfo!!.hasUpdate) {
            Text("发现新版本: " + updateInfo!!.latestVersion, color = MaterialTheme.colorScheme.primary)
        } else {
            Text("已是最新版本", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    if (showUpdateDialog && updateInfo != null) {
        AlertDialog(
            onDismissRequest = { showUpdateDialog = false },
            title = { Text("发现新版本") },
            text = { Text("新版本 " + updateInfo!!.latestVersion + " 已发布，是否立即更新？") },
            confirmButton = {
                TextButton(onClick = {
                    val url = if (updateInfo!!.downloadUrl.isNotEmpty()) updateInfo!!.downloadUrl else "https://github.com/xyouo/SafeBaiyun/releases/latest"
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    showUpdateDialog = false
                }) { Text("更新") }
            },
            dismissButton = {
                TextButton(onClick = { showUpdateDialog = false }) { Text("稍后") }
            }
        )
    }
}

@Composable
fun AppHelper() {
    Text(text = "关于软件", style = MaterialTheme.typography.titleLarge)
    Text(text = "本软件是广州市白云区蓝牙门禁的离线版本，只需要门禁的mac地址以及加密key即可开门，无需网络。支持添加多个门禁设备。")
    Text(text = "使用方法", modifier = Modifier.padding(top = 8.dp), style = MaterialTheme.typography.titleLarge)
    Text(text = "1. 提取MAC地址及加密密钥")
    Text(text = "1.1 Root方式提取")
    Text(text = "有 root 的Android 手机可以直接前往 /data/data/com.huacheng.baiyunuser/databases/目录 找到数据库文件 (32位 hash).db")
    Text(text = "1.2 无Root方式提取")
    Text(text = "使用MIUI的备份功能提取数据文件，前往 设置->我的设备->备份与恢复->手机备份 只选中平安回家这个软件进行备份即可，备份完成之后用 MT 管理器打开 /sdcard/MIUI/backup/AllBackup/时间/平安回家(com.huacheng.baiyunuser.bak)压缩包 然后在压缩包中找到apps/com.huacheng.baiyunuser/db/(32位 hash).db将其解压出来。")
    Text(text = "1.3 查看DB文件")
    Text(text = "随便找个支持查看 sqlite 数据库的软件，打开.db文件，查询t_device表， 其中 MAC_NUM 是 mac 地址 PRODUCT_KEY 就是加密key")
    Text(text = "2. 点击软件右上角编辑按钮，添加门禁设备（支持多个），分别填写名称、Mac地址和Key")
    Text(text = "3. 在主页面选择对应设备点击「开门」按钮即可", fontWeight = FontWeight.Medium)
}

@Preview
@Composable
private fun HelpPreview() {
    HelpView(navController = rememberNavController())
}