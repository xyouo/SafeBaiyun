package cn.huacheng.safebaiyun.compose

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
    var showOnlineFetchSheet by remember { mutableStateOf(false) }
    var editingDevice by remember { mutableStateOf<Device?>(null) }
    var deleteConfirmDevice by remember { mutableStateOf<Device?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("设备管理", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 12.dp))

            devices.forEach { device ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Text(device.name, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            VariableValueRow(label = "macNum", value = device.mac)
                            VariableValueRow(label = "productKey", value = device.key)
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
                Text("暂无设备", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 16.dp))
            }

            Button(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .fillMaxWidth(),
                onClick = { editingDevice = null; showEditSheet = true }
            ) {
                Icon(Icons.Default.Add, contentDescription = "添加", modifier = Modifier.size(18.dp))
                Text("手动添加", modifier = Modifier.padding(start = 4.dp))
            }

            Button(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .fillMaxWidth(),
                onClick = { showOnlineFetchSheet = true }
            ) {
                Text("在线获取")
            }
        }
    }

    if (showEditSheet) {
        DeviceEditSheet(
            device = editingDevice,
            onDismiss = { showEditSheet = false; editingDevice = null },
            onSave = { device ->
                if (editingDevice != null) DataRepo.updateDevice(device) else DataRepo.addDevice(device)
                devices = DataRepo.readDevices()
                onDevicesChanged()
                showEditSheet = false
                editingDevice = null
            }
        )
    }

    if (showOnlineFetchSheet) {
        OnlineDeviceFetchSheet(
            onDismiss = { showOnlineFetchSheet = false },
            onAddDevice = { remoteDevice ->
                DataRepo.addDevice(remoteDevice.toDevice())
                devices = DataRepo.readDevices()
                onDevicesChanged()
            }
        )
    }

    deleteConfirmDevice?.let { device ->
        AlertDialog(
            onDismissRequest = { deleteConfirmDevice = null },
            title = { Text("删除设备") },
            text = { Text("确定删除 ${device.name}？") },
            confirmButton = {
                TextButton(onClick = {
                    DataRepo.deleteDevice(device.id)
                    devices = DataRepo.readDevices()
                    onDevicesChanged()
                    deleteConfirmDevice = null
                }) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deleteConfirmDevice = null }) { Text("取消") } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeviceEditSheet(device: Device?, onDismiss: () -> Unit, onSave: (Device) -> Unit) {
    val isEdit = device != null
    var address by remember { mutableStateOf(device?.name ?: "") }
    var mac by remember { mutableStateOf(device?.mac ?: "") }
    var key by remember { mutableStateOf(device?.key ?: "") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (isEdit) "编辑设备" else "添加设备", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 12.dp))

            val fieldModifier = Modifier
                .padding(8.dp)
                .fillMaxWidth()
            OutlinedTextField(modifier = fieldModifier, value = address, onValueChange = { address = it }, label = { Text("address") }, placeholder = { Text("门禁地址") })
            OutlinedTextField(modifier = fieldModifier, value = mac, onValueChange = { mac = it }, label = { Text("macNum") }, placeholder = { Text("12:34:56:78:9A:BC") })
            OutlinedTextField(modifier = fieldModifier, value = key, onValueChange = { key = it }, label = { Text("productKey") }, placeholder = { Text("1234567890ABCDEF") })

            Button(
                modifier = Modifier.padding(8.dp),
                onClick = {
                    val finalAddress = if (address.isNotBlank()) address else DataRepo.generateUniqueName()
                    onSave(Device(id = device?.id ?: UUID.randomUUID().toString(), name = finalAddress, mac = mac, key = key))
                },
                enabled = mac.isNotBlank() && key.isNotBlank()
            ) { Text(if (isEdit) "保存" else "添加") }
        }
    }
}

@Composable
private fun VariableValueRow(label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Surface(
            modifier = Modifier.width(78.dp),
            shape = MaterialTheme.shapes.extraSmall,
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
            contentColor = MaterialTheme.colorScheme.primary
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
            )
        }
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 10.dp)
        )
    }
}
