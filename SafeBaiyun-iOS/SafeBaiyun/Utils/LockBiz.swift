import Foundation

struct LockBiz {
    static func encryptData(inputData: [UInt8], headerData: [UInt8], keyString: String) -> [UInt8]? {
        let keyBytes = ByteUtil.hexToBytes(keyString)
        guard keyBytes.isEmpty == false, headerData.count >= 6 else { return nil }
        let headerBytesSubset = Array(headerData[2..<6])

        var sum = inputData.reduce(0) { $0 + Int($1) }
        sum += keyBytes.reduce(0) { $0 + Int($1) }
        let sumBytes: [UInt8] = [UInt8(sum & 0xFF), UInt8((sum >> 8) & 0xFF)]

        var paddedData = sumBytes + inputData
        while paddedData.count % 8 != 0 {
            paddedData.append(0)
        }

        guard let encrypted = FDes.encrypt(data: Data(paddedData), key: Data(keyBytes)) else {
            return nil
        }
        let encryptedBlock = [UInt8](encrypted.prefix(8))

        let finalLen = encryptedBlock.count + 12
        guard finalLen <= 255 else { return nil }

        var finalData = [UInt8](repeating: 0, count: finalLen)
        finalData[0] = 0xA5
        finalData[1] = UInt8(finalLen)
        finalData[2] = 5
        finalData[3] = headerBytesSubset[0]
        finalData[4] = headerBytesSubset[1]
        finalData[5] = headerBytesSubset[2]
        finalData[6] = headerBytesSubset[3]
        finalData[7] = 0
        finalData[8] = 1
        finalData[9] = 7
        for i in 0..<encryptedBlock.count {
            finalData[10 + i] = encryptedBlock[i]
        }
        finalData[finalData.count - 2] = 0
        finalData[finalData.count - 1] = 90

        let checksum = finalData.reduce(0) { $0 + Int($1) }
        finalData[finalData.count - 2] = UInt8((~checksum) & 0xFF)

        return finalData
    }
}
