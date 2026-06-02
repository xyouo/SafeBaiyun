package cn.huacheng.safebaiyun.compose

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import cn.huacheng.safebaiyun.R
import cn.huacheng.safebaiyun.unlock.DataRepo
import cn.huacheng.safebaiyun.unlock.UnlockRepo
import cn.huacheng.safebaiyun.util.showToast

@Composable
fun MainView(navController: NavHostController) {
    val context = LocalContext.current
    val hasPermission = remember { mutableStateOf(false) }
    val showDeviceSheet = remember { mutableStateOf(false) }
    val devices = remember { mutableStateListOf(*DataRepo.readDevices().toTypedArray()) }

    SideEffect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission.value =
                context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            hasPermission.value = true
        }
    }

    Column {
        MainTopBar(onEditClick = { showDeviceSheet.value = true }, onHelperClick = {
            navController.navigate("helper")
        })
        Box(
            modifier = Modifier.fillMaxSize().padding(8.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            if (!hasPermission.value) {
                PermissionView(hasPermission)
            } else if (devices.isEmpty()) {
                EmptyDeviceView(onClick = { showDeviceSheet.value = true })
            } else {
                DeviceListView(devices = devices, onRefresh = {
                    devices.clear()
                    devices.addAll(DataRepo.readDevices())
                })
            }
        }
                if (showDeviceSheet.value) {
            DeviceListSheet(
                onDevicesChanged = {
                    devices.clear()
                    devices.addAll(DataRepo.readDevices())
                },
                onDismiss = {
                    showDeviceSheet.value = false
                    devices.clear()
                    devices.addAll(DataRepo.readDevices())
                }
            )
        }
    }
}

@Composable
private fun EmptyDeviceView(onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier.fillMaxSize()
    ) {
        Text("暂无门禁设备", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.height(8.dp))
        Text("点击右上角编辑按钮添加设备", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onClick) { Text("添加设备") }
    }
}

@Composable
private fun DeviceListView(devices: MutableList<cn.huacheng.safebaiyun.unlock.Device>, onRefresh: () -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(devices, key = { it.id }) { device ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(device.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(device.mac, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Column {
                        if (devices.indexOf(device) > 0) {
                            IconButton(onClick = {
                                DataRepo.moveDeviceUp(device.id)
                                onRefresh()
                            }) {
                                Icon(Icons.Default.KeyboardArrowUp, contentDescription = "上移", modifier = Modifier.size(20.dp))
                            }
                        }
                        if (devices.indexOf(device) < devices.size - 1) {
                            IconButton(onClick = {
                                DataRepo.moveDeviceDown(device.id)
                                onRefresh()
                            }) {
                                Icon(Icons.Default.KeyboardArrowDown, contentDescription = "下移", modifier = Modifier.size(20.dp))
                            }
                        }
                    }
                    Button(
                        onClick = {
                            showToast("开始解锁：${device.name}")
                            UnlockRepo.unlock(device)
                        },
                        modifier = Modifier.size(width = 80.dp, height = 40.dp)
                    ) {
                        Text("开门", fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun PermissionView(hasPermission: MutableState<Boolean>) {
    val requestPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted -> hasPermission.value = isGranted }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier.fillMaxSize()
    ) {
        Button(modifier = Modifier.size(144.dp, 56.dp), onClick = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                requestPermissionLauncher.launch(Manifest.permission.BLUETOOTH_CONNECT)
        }) {
            Text(text = stringResource(id = R.string.request_permission), fontSize = 18.sp)
        }
    }
}

