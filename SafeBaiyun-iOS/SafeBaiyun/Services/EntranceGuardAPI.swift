import Foundation
import UIKit

struct RemoteDoorDevice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let mac: String
    let key: String
    let bluetoothName: String

    var device: Device {
        Device(
            name: name,
            mac: ByteUtil.normalizeMac(mac),
            key: key,
            bluetoothName: bluetoothName
        )
    }
}

final class EntranceGuardAPI {
    static let shared = EntranceGuardAPI()

    private struct Auth {
        let token: String
        let loginUser: String
        let phone: String
    }

    private let baseURL = URL(string: "https://www.pinganbaiyun.cn")!

    func fetchDevices(phone: String, idCard: String) async throws -> [RemoteDoorDevice] {
        let normalizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIdCard = idCard.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedPhone.isEmpty == false, normalizedIdCard.isEmpty == false else {
            throw FetchError.message("请填写手机号和身份证号")
        }

        let auth = try await login(phone: normalizedPhone, idCard: normalizedIdCard)
        defer {
            Task { try? await logout(auth: auth) }
        }

        let response = try await request(
            path: "/baiyunuser/entranceguard/getList",
            payload: [
                "pageNum": 0,
                "pages": 0,
                "pageSize": 0
            ],
            extraHeaders: [
                "TOKEN": auth.token,
                "LOGIN_USER": auth.loginUser
            ]
        )
        return parseDoorDevices(from: response)
    }

    private func login(phone: String, idCard: String) async throws -> Auth {
        let response = try await request(
            path: "/baiyunuser/account/login/v1",
            payload: [
                "sex": 0,
                "idcardNo": idCard,
                "deviceInfo": [
                    "osVersion": UIDeviceInfo.osVersion,
                    "wifiMac": "02:00:00:00:00:00",
                    "brand": "Apple",
                    "os": 0,
                    "udid": UUID().uuidString,
                    "appVersion": "1.3.6",
                    "imsi": "46015",
                    "model": UIDeviceInfo.model
                ],
                "faceUploadCount": 0,
                "isreal": 0,
                "age": 0,
                "appVersion": "1.3.6",
                "phone": phone
            ]
        )

        guard boolValue(response["state"]) == true, (stringValue(response["code"]) ?? "") == "0000" else {
            throw FetchError.message(stringValue(response["msg"]) ?? "登录失败")
        }
        guard let token = stringValue(response["extension"]), token.isEmpty == false else {
            throw FetchError.message("登录返回缺少 token")
        }
        guard
            let obj = response["obj"] as? [String: Any],
            let loginUser = stringValue(obj["id"]),
            loginUser.isEmpty == false
        else {
            throw FetchError.message("登录返回缺少用户信息")
        }
        return Auth(token: token, loginUser: loginUser, phone: phone)
    }

    private func logout(auth: Auth) async throws {
        _ = try await request(
            path: "/baiyunuser/account/loginOut",
            payload: ["phone": auth.phone],
            extraHeaders: [
                "TOKEN": auth.token,
                "LOGIN_USER": auth.loginUser
            ]
        )
    }

    private func request(path: String, payload: [String: Any], extraHeaders: [String: String] = [:]) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw FetchError.message("请求地址无效")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("www.pinganbaiyun.cn", forHTTPHeaderField: "Host")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-Hans-US;q=1, en-US;q=0.9", forHTTPHeaderField: "Accept-Language")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.message("请求失败")
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw FetchError.message("返回数据格式错误")
        }
        return dict
    }

    private func parseDoorDevices(from response: [String: Any]) -> [RemoteDoorDevice] {
        let records = collectDoorRecords(from: response)
        return records.compactMap { record in
            let name = stringValue(record["address"]) ?? stringValue(record["name"]) ?? ""
            guard let mac = stringValue(record["macNum"]), ByteUtil.macToBytes(mac).count == 6 else {
                return nil
            }
            guard let key = stringValue(record["productKey"]), ByteUtil.hexToBytes(key).isEmpty == false else {
                return nil
            }
            let bluetoothName = ByteUtil.normalizeBluetoothName(stringValue(record["bluetoothName"]) ?? "")
            return RemoteDoorDevice(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                mac: mac,
                key: key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                bluetoothName: bluetoothName
            )
        }
    }

    private func collectDoorRecords(from value: Any) -> [[String: Any]] {
        if let array = value as? [Any] {
            return array.flatMap { collectDoorRecords(from: $0) }
        }
        guard let dict = value as? [String: Any] else {
            return []
        }
        var records: [[String: Any]] = []
        if let list = dict["data_list"] as? [[String: Any]] {
            records.append(contentsOf: list)
        }
        if let obj = dict["obj"] {
            records.append(contentsOf: collectDoorRecords(from: obj))
        }
        if dict["macNum"] != nil || dict["productKey"] != nil {
            records.append(dict)
        }
        return records
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}

enum FetchError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private enum UIDeviceInfo {
    static var osVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        return "15.0"
        #endif
    }

    static var model: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }
}
