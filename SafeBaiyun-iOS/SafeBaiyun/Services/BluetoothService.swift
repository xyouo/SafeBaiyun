import Foundation
import CoreBluetooth

class BluetoothService: NSObject, ObservableObject {
    static let shared = BluetoothService()

    private struct Candidate {
        let peripheral: CBPeripheral
        let rssi: Int
        let advertisesMagicService: Bool
        let advertisesDoorDataService: Bool
        let nameLooksLikeDoor: Bool
        let isCached: Bool
    }

    private let magicService = CBUUID(string: "14839AC4-7D7E-415C-9A42-167340CF2339")
    private let doorDataService = CBUUID(string: "0734594A-A8E7-4B1A-A6B1-CD5243059A57")
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
    private var cachedPeripheralId: UUID?

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
        log("开始开门: name=\(device.name), mac=\(device.mac), keyLength=\(device.key.count)")

        guard centralManager.state == .poweredOn else {
            log("蓝牙状态不是 poweredOn: \(centralManager.state.rawValue)")
            finish(false, message: "蓝牙未开启")
            return
        }

        cachedPeripheralId = DataService.shared.cachedPeripheralId(for: device.id)
        if let cachedId = cachedPeripheralId {
            log("存在上次写入成功的 iOS 外设 UUID: \(cachedId.uuidString)。当前版本仅显示和记录缓存，不用缓存优先连接")
        } else {
            log("没有缓存的 iOS 外设 UUID，开始扫描")
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        log("扫描已启动，service=nil，RSSI 阈值=-88")

        scheduleScanSettle(after: 0.8)

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.log("总体超时，未找到可用门禁")
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
        cachedPeripheralId = nil
        if let peripheral = peripheral {
            log("重置连接，取消当前设备: \(describe(peripheral))")
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
        log("结束开门: success=\(success), message=\(message)")
        onComplete?(success)
        if let peripheral = peripheral {
            log("断开设备: \(describe(peripheral))")
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
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "-"
        let advertisesMagicService = services.contains(magicService)
        let advertisesDoorDataService = services.contains(doorDataService)
        let displayName = peripheral.name ?? localName
        let nameLooksLikeDoor = displayName.uppercased().hasPrefix("BY")
        let isCached = peripheral.identifier == cachedPeripheralId
        let isLikelyDoor = advertisesMagicService || advertisesDoorDataService || nameLooksLikeDoor
        log("发现设备: \(describe(peripheral)), name=\(localName), rssi=\(rssi), magic=\(advertisesMagicService), doorData=\(advertisesDoorDataService), byName=\(nameLooksLikeDoor), cached=\(isCached), services=\(services.map { $0.uuidString }.joined(separator: ","))")

        guard isLikelyDoor else {
            log("忽略非门禁候选: \(describe(peripheral))")
            return
        }

        candidates.append(Candidate(
            peripheral: peripheral,
            rssi: rssi,
            advertisesMagicService: advertisesMagicService,
            advertisesDoorDataService: advertisesDoorDataService,
            nameLooksLikeDoor: nameLooksLikeDoor,
            isCached: isCached
        ))

        if advertisesMagicService || advertisesDoorDataService {
            log("发现门禁广播特征，立即尝试连接")
            scanSettleWorkItem?.cancel()
            scanSettleWorkItem = nil
            connectNextCandidate()
        } else if peripheral == nil && scanSettleWorkItem == nil {
            scheduleScanSettle(after: 0.4)
        }
    }

    private func scheduleScanSettle(after delay: TimeInterval) {
        scanSettleWorkItem?.cancel()
        let settleWorkItem = DispatchWorkItem { [weak self] in
            self?.scanSettleWorkItem = nil
            self?.connectNextCandidate()
        }
        scanSettleWorkItem = settleWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: settleWorkItem)
    }

    private func connectNextCandidate() {
        guard isUnlocking, !didStartUnlock, peripheral == nil else { return }
        candidateWorkItem?.cancel()
        candidateWorkItem = nil

        candidates.sort {
            if $0.advertisesMagicService != $1.advertisesMagicService {
                return $0.advertisesMagicService && !$1.advertisesMagicService
            }
            if $0.advertisesDoorDataService != $1.advertisesDoorDataService {
                return $0.advertisesDoorDataService && !$1.advertisesDoorDataService
            }
            if $0.nameLooksLikeDoor != $1.nameLooksLikeDoor {
                return $0.nameLooksLikeDoor && !$1.nameLooksLikeDoor
            }
            return $0.rssi > $1.rssi
        }

        guard !candidates.isEmpty else { return }

        let next = candidates.removeFirst().peripheral
        peripheral = next
        next.delegate = self
        log("尝试连接候选: \(describe(next))")
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
            log("拒绝当前候选并尝试下一个: \(describe(peripheral))")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        connectNextCandidate()
    }

    private func describe(_ peripheral: CBPeripheral) -> String {
        "\(peripheral.name ?? "-")/\(peripheral.identifier.uuidString)"
    }

    private func log(_ message: String) {
        DebugLogStore.shared.append(message)
    }
}

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("蓝牙已就绪")
        }
        DebugLogStore.shared.append("蓝牙状态变化: \(central.state.rawValue)")
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
        log("已连接: \(describe(peripheral))，开始发现服务")
        peripheral.discoverServices(nil)

        let workItem = DispatchWorkItem { [weak self] in
            self?.rejectCurrentCandidate()
        }
        candidateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("连接失败: \(describe(peripheral)), error=\(error?.localizedDescription ?? "-")")
        rejectCurrentCandidate()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("连接断开: \(describe(peripheral)), error=\(error?.localizedDescription ?? "-")")
        if isUnlocking && !didStartUnlock && self.peripheral?.identifier == peripheral.identifier {
            self.peripheral = nil
            connectNextCandidate()
        }
    }
}

extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            log("发现服务失败: \(error?.localizedDescription ?? "-")")
            rejectCurrentCandidate()
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == magicService }) else {
            let services = peripheral.services?.map { $0.uuid.uuidString }.joined(separator: ",") ?? "-"
            log("当前设备没有门禁服务，services=\(services)")
            rejectCurrentCandidate()
            return
        }

        log("找到门禁服务: \(service.uuid.uuidString)，开始发现特征")
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            log("发现特征失败: \(error?.localizedDescription ?? "-")")
            rejectCurrentCandidate()
            return
        }

        guard let chars = service.characteristics else {
            log("门禁服务没有特征")
            rejectCurrentCandidate()
            return
        }

        for char in chars {
            let props = char.properties
            log("特征: \(char.uuid.uuidString), properties=\(props.rawValue)")
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
            log("没有找到可读或可写特征: read=\(readChar != nil), write=\(writeChar != nil)")
            rejectCurrentCandidate()
            return
        }

        candidateWorkItem?.cancel()
        candidateWorkItem = nil
        log("读取门禁随机数据: \(readChar.uuid.uuidString)")
        peripheral.readValue(for: readChar)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if didStartUnlock { return }
        guard let value = characteristic.value, let writeChar = writeChar, let device = currentDevice else {
            log("读取门禁数据失败: value=\(characteristic.value?.count ?? 0), write=\(writeChar != nil), device=\(currentDevice != nil)")
            finish(false, message: "读取门禁数据失败")
            return
        }

        didStartUnlock = true

        let inputBytes = [UInt8](value)
        let headerBytes = ByteUtil.macToBytes(device.mac)
        log("读取完成: bytes=\(inputBytes.count)，开始加密")

        guard let encrypted = LockBiz.encryptData(inputData: inputBytes, headerData: headerBytes, keyString: device.key) else {
            log("加密失败: macBytes=\(headerBytes.count), keyLength=\(device.key.count)")
            finish(false, message: "加密失败")
            return
        }

        log("写入开门指令: char=\(writeChar.uuid.uuidString), bytes=\(encrypted.count), type=\(writeType == .withResponse ? "withResponse" : "withoutResponse")")
        peripheral.writeValue(Data(encrypted), for: writeChar, type: writeType)
        if writeType == .withoutResponse {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.log("指令已发送，但 writeWithoutResponse 没有系统写入确认，不更新缓存")
                self?.finish(true, message: "指令已发送")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            if let device = currentDevice {
                DataService.shared.saveCachedPeripheralId(peripheral.identifier, for: device.id)
                log("蓝牙写入成功，已缓存 iOS 外设 UUID: \(peripheral.identifier.uuidString)。这只代表指令写入成功，不代表门禁一定已开门")
            }
            finish(true, message: "指令已发送")
        } else {
            log("写入失败: \(error?.localizedDescription ?? "-")")
            finish(false, message: "开门失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
}
