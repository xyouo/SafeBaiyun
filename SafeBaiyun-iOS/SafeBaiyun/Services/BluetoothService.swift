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
        let bluetoothNameMatches: Bool
        let macNameMatches: Bool
        let isTrustedCached: Bool
        let displayName: String

        var matchesCurrentDevice: Bool {
            bluetoothNameMatches || macNameMatches
        }

        var priority: Int {
            var score = rssi
            if bluetoothNameMatches { score += 700 }
            if macNameMatches { score += 600 }
            if isTrustedCached { score += 500 }
            if advertisesMagicService { score += 250 }
            if advertisesDoorDataService { score += 180 }
            if nameLooksLikeDoor { score += 100 }
            return score
        }
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
    private var serviceScanWorkItem: DispatchWorkItem?
    private var discoveryLogCache: [UUID: String] = [:]
    private var candidatesById: [UUID: Candidate] = [:]
    private var candidates: [Candidate] = []
    private var cachedPeripheralId: UUID?
    private var connectedCandidate: Candidate?

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
            log("存在缓存的 iOS 外设 UUID: \(cachedId.uuidString)。会先扫描确认它属于当前门禁，再优先连接")
        } else {
            log("没有缓存的 iOS 外设 UUID，开始扫描")
        }

        startScan(withServices: nil, label: "nil")
        scheduleScanSettle(after: 0.8)
        scheduleServiceFilteredScan()

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.log("总体超时，未找到可用门禁")
            self?.finish(false, message: "未找到门禁设备")
        }
        overallTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 16, execute: timeoutWorkItem)
    }

    private func resetConnection() {
        overallTimeoutWorkItem?.cancel()
        scanSettleWorkItem?.cancel()
        candidateWorkItem?.cancel()
        serviceScanWorkItem?.cancel()
        overallTimeoutWorkItem = nil
        scanSettleWorkItem = nil
        candidateWorkItem = nil
        serviceScanWorkItem = nil
        didStartUnlock = false
        writeChar = nil
        readChar = nil
        writeType = .withResponse
        notifyChars = []
        discoveryLogCache.removeAll()
        candidatesById.removeAll()
        candidates.removeAll()
        cachedPeripheralId = nil
        connectedCandidate = nil
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
        serviceScanWorkItem?.cancel()
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
        connectedCandidate = nil
        candidates.removeAll()
        candidatesById.removeAll()
    }

    private func startScan(withServices services: [CBUUID]?, label: String) {
        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        log("扫描已启动，service=\(label)，RSSI 阈值=-88，允许重复广播更新候选")
    }

    private func scheduleServiceFilteredScan() {
        serviceScanWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isUnlocking, self.peripheral == nil, !self.didStartUnlock else { return }
            self.log("普通扫描暂未命中当前门禁，切换为门禁广播特征扫描")
            self.startScan(withServices: [self.doorDataService], label: self.doorDataService.uuidString)
            self.scheduleScanSettle(after: 1.0)
        }
        serviceScanWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    private func enqueue(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: Int) {
        guard isUnlocking, rssi > -88 else { return }

        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "-"
        let advertisesMagicService = services.contains(magicService)
        let advertisesDoorDataService = services.contains(doorDataService)
        let displayName = peripheral.name ?? localName
        let nameLooksLikeDoor = displayName.uppercased().hasPrefix("BY")
        let bluetoothNameMatches = matchesBluetoothName(displayName)
        let macNameMatches = matchesDeviceMac(displayName)
        let isCached = peripheral.identifier == cachedPeripheralId
        let hasBluetoothTarget = currentDevice.map { !$0.bluetoothName.isEmpty } ?? false
        let isTrustedCached = isCached && (!hasBluetoothTarget || bluetoothNameMatches)
        let isLikelyDoor = advertisesMagicService || advertisesDoorDataService || nameLooksLikeDoor || bluetoothNameMatches || macNameMatches
        let servicesText = services.map { $0.uuidString }.joined(separator: ",")
        let signature = "\(isLikelyDoor)-\(localName)-\(advertisesMagicService)-\(advertisesDoorDataService)-\(nameLooksLikeDoor)-\(bluetoothNameMatches)-\(macNameMatches)-\(isCached)-\(isTrustedCached)-\(servicesText)"

        let shouldLogDiscovery = discoveryLogCache[peripheral.identifier] != signature
        if shouldLogDiscovery {
            discoveryLogCache[peripheral.identifier] = signature
            log("发现设备: \(describe(peripheral)), name=\(localName), rssi=\(rssi), magic=\(advertisesMagicService), doorData=\(advertisesDoorDataService), byName=\(nameLooksLikeDoor), btNameMatch=\(bluetoothNameMatches), macMatch=\(macNameMatches), cached=\(isCached), trustedCached=\(isTrustedCached), services=\(servicesText)")
        }

        if isCached && hasBluetoothTarget && nameLooksLikeDoor && !bluetoothNameMatches && !macNameMatches, let device = currentDevice {
            log("缓存外设已扫描到，但名称 \(displayName) 与当前门禁 \(device.bluetoothName) 不匹配，已忽略并清除缓存")
            DataService.shared.clearCachedPeripheral(for: device.id)
            cachedPeripheralId = nil
        }

        guard isLikelyDoor else {
            if shouldLogDiscovery {
                log("忽略非门禁候选: \(describe(peripheral))")
            }
            return
        }

        let candidate = Candidate(
            peripheral: peripheral,
            rssi: rssi,
            advertisesMagicService: advertisesMagicService,
            advertisesDoorDataService: advertisesDoorDataService,
            nameLooksLikeDoor: nameLooksLikeDoor,
            bluetoothNameMatches: bluetoothNameMatches,
            macNameMatches: macNameMatches,
            isTrustedCached: isTrustedCached,
            displayName: displayName
        )

        if let existing = candidatesById[peripheral.identifier], existing.priority > candidate.priority {
            return
        }

        candidatesById[peripheral.identifier] = candidate
        candidates.removeAll { $0.peripheral.identifier == peripheral.identifier }
        candidates.append(candidate)

        let hasExactTarget = hasBluetoothTarget || (currentDevice.map { !$0.mac.isEmpty } ?? false)
        if bluetoothNameMatches || macNameMatches || isTrustedCached || (advertisesMagicService && !hasExactTarget) {
            if bluetoothNameMatches {
                log("发现与 bluetoothName 匹配的门禁广播，立即尝试连接")
            } else if isTrustedCached {
                log("发现可信缓存门禁广播，优先尝试连接")
            } else {
                log(macNameMatches ? "发现与当前 MAC 匹配的门禁广播，立即尝试连接" : "发现门禁主服务广播，立即尝试连接")
            }
            scanSettleWorkItem?.cancel()
            scanSettleWorkItem = nil
            connectNextCandidate()
        } else if self.peripheral == nil && scanSettleWorkItem == nil {
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
            if $0.bluetoothNameMatches != $1.bluetoothNameMatches {
                return $0.bluetoothNameMatches && !$1.bluetoothNameMatches
            }
            if $0.macNameMatches != $1.macNameMatches {
                return $0.macNameMatches && !$1.macNameMatches
            }
            if $0.isTrustedCached != $1.isTrustedCached {
                return $0.isTrustedCached && !$1.isTrustedCached
            }
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

        let nextCandidate = candidates.removeFirst()
        let next = nextCandidate.peripheral
        peripheral = next
        connectedCandidate = nextCandidate
        next.delegate = self
        log("尝试连接候选: \(describe(next))，match=\(nextCandidate.matchesCurrentDevice), cached=\(nextCandidate.isTrustedCached), rssi=\(nextCandidate.rssi)")
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
        connectedCandidate = nil
        connectNextCandidate()
    }

    private func describe(_ peripheral: CBPeripheral) -> String {
        "\(peripheral.name ?? "-")/\(peripheral.identifier.uuidString)"
    }

    private func matchesDeviceMac(_ name: String) -> Bool {
        guard let device = currentDevice else { return false }
        let normalizedName = name.uppercased().filter { $0.isLetter || $0.isNumber }
        let hexCharacters = Set("0123456789ABCDEF")
        let macHex = device.mac.uppercased().filter { hexCharacters.contains($0) }
        guard macHex.count >= 8 else { return false }

        let suffixes = [10, 9, 8]
            .filter { macHex.count >= $0 }
            .map { String(macHex.suffix($0)) }

        return suffixes.contains { normalizedName.contains($0) }
    }

    private func matchesBluetoothName(_ name: String) -> Bool {
        guard let device = currentDevice, device.bluetoothName.isEmpty == false else { return false }
        let normalizedName = ByteUtil.normalizeBluetoothName(name)
        return normalizedName == device.bluetoothName || normalizedName.contains(device.bluetoothName)
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
            self.connectedCandidate = nil
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
        let headerBytes = ByteUtil.bluetoothNameHeaderBytes(device.bluetoothName) ?? ByteUtil.macToBytes(device.mac)
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
                let canTrustCache = connectedCandidate?.matchesCurrentDevice == true || (device.bluetoothName.isEmpty && connectedCandidate?.advertisesMagicService == true)
                if canTrustCache {
                    DataService.shared.saveCachedPeripheralId(peripheral.identifier, for: device.id)
                    log("蓝牙写入成功，已缓存匹配当前门禁的 iOS 外设 UUID: \(peripheral.identifier.uuidString)。这只代表指令写入成功，不代表门禁一定已开门")
                } else {
                    log("蓝牙写入成功，但候选未确认匹配当前门禁，不更新缓存: \(peripheral.identifier.uuidString)")
                }
            }
            finish(true, message: "指令已发送")
        } else {
            log("写入失败: \(error?.localizedDescription ?? "-")")
            finish(false, message: "开门失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
}
