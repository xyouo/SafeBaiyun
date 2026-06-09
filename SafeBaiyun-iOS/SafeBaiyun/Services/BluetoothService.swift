import Foundation
import CoreBluetooth

class BluetoothService: NSObject, ObservableObject {
    static let shared = BluetoothService()

    private struct Candidate {
        let peripheral: CBPeripheral
        let rssi: Int
        let advertisesMagicService: Bool
    }

    private let magicService = CBUUID(string: "14839AC4-7D7E-415C-9A42-167340CF2339")
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var readChar: CBCharacteristic?
    private var writeType: CBCharacteristicWriteType = .withResponse
    private var notifyChars: [CBCharacteristic] = []
    private var currentDevice: Device?
    private var didStartUnlock = false
    private var overallTimeoutWorkItem: DispatchWorkItem?
    private var scanSettleWorkItem: DispatchWorkItem?
    private var candidateWorkItem: DispatchWorkItem?
    private var discoveredIds = Set<UUID>()
    private var candidates: [Candidate] = []

    @Published var isUnlocking = false
    @Published var statusMessage = ""

    var onComplete: ((Bool) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func unlock(device: Device) {
        guard !isUnlocking else { return }
        resetConnection()
        currentDevice = device
        isUnlocking = true
        statusMessage = "正在开门..."

        guard centralManager.state == .poweredOn else {
            finish(false, message: "蓝牙未开启")
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        let settleWorkItem = DispatchWorkItem { [weak self] in
            self?.connectNextCandidate()
        }
        scanSettleWorkItem = settleWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: settleWorkItem)

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish(false, message: "未找到门禁设备")
        }
        overallTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeoutWorkItem)
    }

    private func resetConnection() {
        overallTimeoutWorkItem?.cancel()
        scanSettleWorkItem?.cancel()
        candidateWorkItem?.cancel()
        overallTimeoutWorkItem = nil
        scanSettleWorkItem = nil
        candidateWorkItem = nil
        didStartUnlock = false
        writeChar = nil
        readChar = nil
        writeType = .withResponse
        notifyChars = []
        discoveredIds.removeAll()
        candidates.removeAll()
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        isUnlocking = false
    }

    private func finish(_ success: Bool, message: String) {
        overallTimeoutWorkItem?.cancel()
        scanSettleWorkItem?.cancel()
        candidateWorkItem?.cancel()
        centralManager.stopScan()
        isUnlocking = false
        statusMessage = message
        onComplete?(success)
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        candidates.removeAll()
    }

    private func enqueue(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: Int) {
        guard rssi > -88 else { return }
        guard !discoveredIds.contains(peripheral.identifier) else { return }

        discoveredIds.insert(peripheral.identifier)
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisesMagicService = services.contains(magicService)
        candidates.append(Candidate(peripheral: peripheral, rssi: rssi, advertisesMagicService: advertisesMagicService))

        if advertisesMagicService {
            scanSettleWorkItem?.cancel()
            connectNextCandidate()
        }
    }

    private func connectNextCandidate() {
        guard isUnlocking, !didStartUnlock, peripheral == nil else { return }
        candidateWorkItem?.cancel()
        candidateWorkItem = nil

        candidates.sort {
            if $0.advertisesMagicService != $1.advertisesMagicService {
                return $0.advertisesMagicService && !$1.advertisesMagicService
            }
            return $0.rssi > $1.rssi
        }

        guard !candidates.isEmpty else { return }

        let next = candidates.removeFirst().peripheral
        peripheral = next
        next.delegate = self
        centralManager.connect(next, options: nil)

        let workItem = DispatchWorkItem { [weak self] in
            self?.rejectCurrentCandidate()
        }
        candidateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func rejectCurrentCandidate() {
        candidateWorkItem?.cancel()
        candidateWorkItem = nil
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        connectNextCandidate()
    }
}

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("蓝牙已就绪")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        enqueue(peripheral, advertisementData: advertisementData, rssi: RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        candidateWorkItem?.cancel()
        candidateWorkItem = nil
        peripheral.discoverServices(nil)

        let workItem = DispatchWorkItem { [weak self] in
            self?.rejectCurrentCandidate()
        }
        candidateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        rejectCurrentCandidate()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if isUnlocking && !didStartUnlock && self.peripheral?.identifier == peripheral.identifier {
            self.peripheral = nil
            connectNextCandidate()
        }
    }
}

extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            rejectCurrentCandidate()
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == magicService }) else {
            rejectCurrentCandidate()
            return
        }

        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            rejectCurrentCandidate()
            return
        }

        guard let chars = service.characteristics else {
            rejectCurrentCandidate()
            return
        }

        for char in chars {
            let props = char.properties
            if props.contains(.read) { readChar = char }
            if props.contains(.write) {
                writeChar = char
                writeType = .withResponse
            } else if props.contains(.writeWithoutResponse), writeChar == nil {
                writeChar = char
                writeType = .withoutResponse
            }
            if props.contains(.notify) || props.contains(.indicate) {
                notifyChars.append(char)
                peripheral.setNotifyValue(true, for: char)
            }
        }

        guard let readChar = readChar, writeChar != nil else {
            rejectCurrentCandidate()
            return
        }

        candidateWorkItem?.cancel()
        candidateWorkItem = nil
        peripheral.readValue(for: readChar)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if didStartUnlock { return }
        guard let value = characteristic.value, let writeChar = writeChar, let device = currentDevice else {
            finish(false, message: "读取门禁数据失败")
            return
        }

        didStartUnlock = true

        let inputBytes = [UInt8](value)
        let headerBytes = ByteUtil.macToBytes(device.mac)

        guard let encrypted = LockBiz.encryptData(inputData: inputBytes, headerData: headerBytes, keyString: device.key) else {
            finish(false, message: "加密失败")
            return
        }

        peripheral.writeValue(Data(encrypted), for: writeChar, type: writeType)
        if writeType == .withoutResponse {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.finish(true, message: "开门指令已发送")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            finish(true, message: "开门成功")
        } else {
            finish(false, message: "开门失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
}
