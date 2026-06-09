import Foundation
import CommonCrypto

struct FDes {
    static func encrypt(data: Data, key: Data) -> Data? {
        var keyBytes = [UInt8](repeating: 0, count: 8)
        let k = [UInt8](key)
        for i in 0..<min(k.count, 8) {
            keyBytes[i] = k[i]
        }

        var outData = Data(count: data.count)
        var outLen = 0
        let dataCount = data.count
        let outDataCount = outData.count

        let status = keyBytes.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                outData.withUnsafeMutableBytes { outPtr in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmDES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, kCCBlockSizeDES,
                        nil,
                        dataPtr.baseAddress, dataCount,
                        outPtr.baseAddress, outDataCount,
                        &outLen
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        outData.count = outLen
        return outData
    }
}
