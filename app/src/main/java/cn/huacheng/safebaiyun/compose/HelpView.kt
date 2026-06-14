package cn.huacheng.safebaiyun.compose

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController

@Composable
fun HelpView(navController: NavController) {
    Column {
        HelperTopBar(navController)
        LazyColumn(modifier = Modifier.padding(12.dp)) {
            item { AppHelper() }
        }
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