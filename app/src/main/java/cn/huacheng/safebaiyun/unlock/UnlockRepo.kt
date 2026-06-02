package cn.huacheng.safebaiyun.unlock

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Build
import android.util.Log
import cn.huacheng.safebaiyun.util.ContextHolder
import cn.huacheng.safebaiyun.util.LockBiz
import cn.huacheng.safebaiyun.unlock.Device
import cn.huacheng.safebaiyun.util.showToast
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch


@SuppressLint("MissingPermission")
object UnlockRepo {

    private const val MAGIC_SERVICE = "14839ac4-7d7e-415c-9a42-167340cf2339"

    private lateinit var gatt: BluetoothGatt

    private lateinit var readableCharacteristic: BluetoothGattCharacteristic

    private lateinit var writeableCharacteristic: BluetoothGattCharacteristic

    private lateinit var config: Pair<String, String>

    private var autoDisconnectJob: Job? = null

    private val logList = mutableListOf("Hello World")
    val logFlow: MutableStateFlow<List<String>> = MutableStateFlow(logList.toList())

    fun unlock() {
        config = DataRepo.readData()
        doUnlock()
    }

    fun unlock(mac: String, key: String) {
        config = mac to key
        doUnlock()
    }

    fun unlock(device: Device) {
        config = device.mac to device.key
        doUnlock()
    }

    private fun doUnlock() {
        val bluetoothAdapter =
            (ContextHolder.get()
                .getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter

        config = DataRepo.readData()

        if (!BluetoothAdapter.checkBluetoothAddress(config.first)) {
            showToast("Mac鍦板潃鏍煎紡閿欒")
            return
        }
        connect(bluetoothAdapter)

        autoDisconnectJob = GlobalScope.launch {
            delay(10000)
            if (isActive) {
                log("10s瓒呮椂锛岃嚜鍔ㄦ柇寮€閾炬帴")
                gatt.disconnect()
                gatt.close()
            }
        }
    }
        val bluetoothAdapter =
            (ContextHolder.get()
                .getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter

        config = DataRepo.readData()

        if (!BluetoothAdapter.checkBluetoothAddress(config.first)) {
            showToast("Mac鍦板潃鏍煎紡閿欒")
            return
        }
        connect(bluetoothAdapter)

        autoDisconnectJob = GlobalScope.launch {
            delay(10000)
            if (isActive) {
                log("10s瓒呮椂锛岃嚜鍔ㄦ柇寮€閾炬帴")
                gatt.disconnect()
                gatt.close()
            }
        }
    }

    private fun connect(bluetoothAdapter: BluetoothAdapter) {
        val remoteDevice = bluetoothAdapter.getRemoteDevice(config.first)
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            remoteDevice.connectGatt(
                ContextHolder.get(),
                false,
                callback,
                BluetoothDevice.TRANSPORT_LE
            )
        } else {
            remoteDevice.connectGatt(
                ContextHolder.get(),
                false,
                callback
            )
        }

        log("灏濊瘯杩炴帴钃濈墮 ${this::gatt.isInitialized}")
    }

    private val callback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            super.onConnectionStateChange(gatt, status, newState)
            log("杩炴帴鐘舵€佹敼鍙?status$status,newState$newState")
            if (newState == BluetoothGatt.STATE_CONNECTED) {
                autoDisconnectJob?.cancel()
                log("寮€濮嬫悳绱㈡湇鍔?)
                gatt?.discoverServices()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            super.onServicesDiscovered(gatt, status)
            log("鎼滅储鏈嶅姟鎴愬姛 $status")
            log("鎼滅储鍒颁互涓嬫湇鍔★細${gatt?.services?.map { it.uuid }?.joinToString(",")}")
            handleService(gatt?.services?.find { it.uuid.toString() == MAGIC_SERVICE })
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            //android13浠ヤ笂璧拌繖閲?
            log("鐗瑰緛鐮佽鍙栧洖璋?$status,${value.size}")
            handleCharacteristicWrite(value)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            status: Int
        ) {
            super.onCharacteristicRead(gatt, characteristic, status)
            //android12鍙婁互涓嬭蛋杩欓噷
            val value = characteristic?.value ?: return
            log("鐗瑰緛鐮佽鍙栧洖璋?$status,${value.size}")
            handleCharacteristicWrite(value)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            status: Int
        ) {
            super.onCharacteristicWrite(gatt, characteristic, status)
            log("鐗瑰緛鐮佸啓鍏ュ洖璋?)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                showToast("寮€闂ㄦ垚鍔?)
            } else {
                showToast("瀵嗛挜鍐欏叆澶辫触")
            }
            gatt?.close()
        }
    }

    /**
     * 鎵惧埌瀵瑰簲鐨刢haracteristic
     */
    private fun handleService(service: BluetoothGattService?) {

        if (service == null) {
            return
        }

        log("寮€濮嬪鐞嗘湇鍔★紝鍏?{service.characteristics.size}涓壒寰?)
        val propCharacteristics = mutableListOf<BluetoothGattCharacteristic>()

        service.characteristics?.forEach {
            log("鐗瑰緛${it.uuid},prop:${it.properties}")
            val properties = it.properties
            if ((properties and 2) != 0) {
                readableCharacteristic = it
            }
            if ((properties and 8) != 0) {
                writeableCharacteristic = it
            }
            if ((properties and 16) != 0) {
                propCharacteristics.add(it)
            }
            if ((properties and 32) != 0) {
                propCharacteristics.add(it)
            }
        }

        handleCharacteristics(propCharacteristics)
    }

    private fun handleCharacteristics(propCharacteristics: MutableList<BluetoothGattCharacteristic>) {
        log("寮€濮嬪鐞嗙壒寰?鍐欏叆瀵瑰簲鏁版嵁")
        propCharacteristics.forEach { characteristic ->
            gatt.setCharacteristicNotification(characteristic, true)
            characteristic.descriptors.forEach {
                if ((characteristic.properties and 16) != 0) {
                    characteristic.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                } else if ((characteristic.properties and 32) != 0) {
                    characteristic.setValue(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
                }

                gatt.writeDescriptor(it)
            }
        }

        val result = gatt.readCharacteristic(readableCharacteristic)
        log("鐗瑰緛鍐欏叆缁撴灉 $result")
    }

    private fun handleCharacteristicWrite(value: ByteArray) {
        log("寮€濮嬪啓鍏ュ瘑閽?)
        val key = LockBiz.encryptData(value, LockBiz.hexToByteArray(config.first), config.second)
        log(key.joinToString())
        writeableCharacteristic.setValue(key)
        writeableCharacteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        val result = gatt.writeCharacteristic(writeableCharacteristic)
        log("瀵嗛挜鍐欏叆缁撴灉 $result")

    }


    @OptIn(DelicateCoroutinesApi::class)
    private fun log(msg: String) {
        println(msg)
//        logList.add(msg)
//        GlobalScope.launch {
//            Log.e("UnlockRepo", "log: $msg")
//            logFlow.emit(logList.toList())
//        }
    }
}
