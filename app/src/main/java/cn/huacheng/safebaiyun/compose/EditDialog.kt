package cn.huacheng.safebaiyun.compose

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import cn.huacheng.safebaiyun.unlock.DataRepo
import cn.huacheng.safebaiyun.unlock.Device
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceListSheet(onDismiss: () -> Unit, onDevicesChanged: () -> Unit = {}) {
    var devices by remember { mutableStateOf(DataRepo.readDevices()) }
    var showEditSheet by remember { mutableStateOf(false) }
    var editingDevice by remember { mutableStateOf<Device?>(null) }
    var deleteConfirmDevice by remember { mutableStateOf<Device?>(null) }
    val context = LocalContext.current
    var showExportDialog by remember { mutableStateOf(false) }
    var exportJson by remember { mutableStateOf<String?>(null) }

    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        val json = exportJson ?: return@rememberLauncherForActivityResult
        if (uri != null) {
            context.contentResolver.openOutputStream(uri)?.use { out ->
                out.write(json.toByteArray())
            }
            Toast.makeText(context, "导出成功", Toast.LENGTH_SHORT).show()
            exportJson = null
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val json = context.contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: return@rememberLauncherForActivityResult
            val count = DataRepo.importDevices(json)
            if (count > 0) {
                devices = DataRepo.readDevices()
                onDevicesChanged()
                Toast.makeText(context, "成功导入 $count 个设备", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(context, "没有新设备可导入", Toast.LENGTH_SHORT).show()
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("设备管理", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 12.dp))

            devices.forEach { device ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(device.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text("MAC: ${device.mac}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("Key: ${device.key}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        IconButton(onClick = { editingDevice = device; showEditSheet = true }) {
                            Icon(Icons.Default.Edit, contentDescription = "编辑", modifier = Modifier.size(20.dp))
                        }
                        IconButton(onClick = { deleteConfirmDevice = device }) {
                            Icon(Icons.Default.Delete, contentDescription = "删除", modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }

            if (devices.isEmpty()) {
                Text("暂无设备，点击下方添加", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 16.dp))
            }

            Button(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth(),
                onClick = { editingDevice = null; showEditSheet = true }
            ) {
                Icon(Icons.Default.Add, contentDescription = "添加", modifier = Modifier.size(18.dp))
                Text("添加设备", modifier = Modifier.padding(start = 4.dp))
            }

            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(modifier = Modifier.weight(1f), onClick = { importLauncher.launch(arrayOf("application/json")) }) {
                    Text("导入配置")
                }
                if (devices.isNotEmpty()) {
                    Button(modifier = Modifier.weight(1f), onClick = { showExportDialog = true }) {
                        Text("导出配置")
                    }
                }
            }
        }
    }

    if (showEditSheet) {
        DeviceEditSheet(device = editingDevice, onDismiss = { showEditSheet = false; editingDevice = null },
            onSave = { device ->
                                            if (editingDevice != null) DataRepo.updateDevice(device)
                            else DataRepo.addDevice(device)
                            devices = DataRepo.readDevices()
                            onDevicesChanged()
                showEditSheet = false; editingDevice = null
            })
    }

    deleteConfirmDevice?.let { device ->
        AlertDialog(
            onDismissRequest = { deleteConfirmDevice = null },
            title = { Text("确认删除") },
            text = { Text("确定要删除「${device.name}」吗？") },
            confirmButton = { TextButton(onClick = {
                DataRepo.deleteDevice(device.id)
                    devices = DataRepo.readDevices()
                    onDevicesChanged()
                    deleteConfirmDevice = null
            }) { Text("删除", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { deleteConfirmDevice = null }) { Text("取消") } }
        )
    }

    if (showExportDialog) {
        ExportDialog(devices = devices, onDismiss = { showExportDialog = false }, onExport = { selectedIds ->
            exportJson = DataRepo.exportDevices(selectedIds)
            exportLauncher.launch("SafeBaiyun-config.json")
            showExportDialog = false
        })
    }
}

@Composable
private fun ExportDialog(devices: List<Device>, onDismiss: () -> Unit, onExport: (List<String>?) -> Unit) {
    var selectAll by remember { mutableStateOf(true) }
    val selectedIds = remember { mutableStateListOf<String>() }

    LaunchedEffect(selectAll) {
        selectedIds.clear()
        if (selectAll) selectedIds.addAll(devices.map { it.id })
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("导出配置") },
        text = {
            Column {
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = selectAll, onCheckedChange = { selectAll = it })
                    Text("全选", style = MaterialTheme.typography.bodyLarge)
                }
                HorizontalDivider()
                devices.forEach { device ->
                    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = device.id in selectedIds, onCheckedChange = { checked ->
                            if (checked) selectedIds.add(device.id) else selectedIds.remove(device.id)
                        })
                        Text(device.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (selectAll) onExport(null)
                    else if (selectedIds.isNotEmpty()) onExport(selectedIds.toList())
                },
                enabled = selectAll || selectedIds.isNotEmpty()
            ) { Text(if (selectAll) "导出全部" else "导出选中 (${selectedIds.size})") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeviceEditSheet(device: Device?, onDismiss: () -> Unit, onSave: (Device) -> Unit) {
    val isEdit = device != null
    var name by remember { mutableStateOf(device?.name ?: "") }
    var mac by remember { mutableStateOf(device?.mac ?: "") }
    var key by remember { mutableStateOf(device?.key ?: "") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (isEdit) "编辑设备" else "添加设备", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 12.dp))

            val modifier = Modifier.padding(8.dp).fillMaxWidth()
            OutlinedTextField(modifier = modifier, value = name, onValueChange = { name = it }, label = { Text("设备名称") }, placeholder = { Text("如：大门、公司门") })
            OutlinedTextField(modifier = modifier, value = mac, onValueChange = { mac = it }, label = { Text("MAC 地址") }, placeholder = { Text("如：12:34:56:78:9A:BC") })
            OutlinedTextField(modifier = modifier, value = key, onValueChange = { key = it }, label = { Text("加密 Key") }, placeholder = { Text("如：123456789ABCDEFG") })

            Button(
                modifier = Modifier.padding(8.dp),
                onClick = {
                    val finalName = name.ifBlank { "门禁" }
                    onSave(Device(id = device?.id ?: UUID.randomUUID().toString(), name = finalName, mac = mac, key = key))
                },
                enabled = mac.isNotBlank() && key.isNotBlank()
            ) { Text(if (isEdit) "保存修改" else "添加") }
        }
    }
}