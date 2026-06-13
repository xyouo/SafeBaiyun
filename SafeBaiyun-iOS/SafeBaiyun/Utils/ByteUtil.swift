import Foundation

struct ByteUtil {
    static func hexToBytes(_ hex: String) -> [UInt8] {
        var hex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        if hex.count % 2 != 0 { hex = "0" + hex }
        var bytes = [UInt8]()
        var startIndex = hex.startIndex
        while startIndex < hex.endIndex {
            let endIndex = hex.index(startIndex, offsetBy: 2)
            if endIndex <= hex.endIndex {
                let byteString = String(hex[startIndex..<endIndex])
                if let byte = UInt8(byteString, radix: 16) {
                    bytes.append(byte)
                }
            }
            startIndex = endIndex
        }
        return bytes
    }

    static func bytesToHex(_ bytes: [UInt8]) -> String {
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func byteToHex(_ byte: UInt8) -> String {
        return String(format: "%02x", byte)
    }

    static func macToBytes(_ mac: String) -> [UInt8] {
        return hexToBytes(mac)
    }

    static func normalizeMac(_ mac: String) -> String {
        let hex = mac
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        guard hex.count == 12 else { return mac.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        var parts: [String] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            parts.append(String(hex[index..<next]))
            index = next
        }
        return parts.joined(separator: ":")
    }

    static func normalizeBluetoothName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func derivedBluetoothName(fromMac mac: String) -> String {
        let hex = mac
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard hex.count >= 9 else { return "" }
        return "BY" + String(hex.suffix(9))
    }

    static func bluetoothNameHeaderBytes(_ name: String) -> [UInt8]? {
        let clean = normalizeBluetoothName(name)
        guard clean.count >= 11 else { return nil }
        let startOffsets = [3, 5, 7, 9]
        var result: [UInt8] = []
        for offset in startOffsets {
            let start = clean.index(clean.startIndex, offsetBy: offset)
            let end = clean.index(start, offsetBy: 2)
            guard let byte = UInt8(String(clean[start..<end]), radix: 16) else {
                return nil
            }
            result.append(byte)
        }
        return result
    }
}
