import Foundation

struct Device: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var mac: String
    var key: String
    var bluetoothName: String

    init(id: String = UUID().uuidString, name: String, mac: String, key: String, bluetoothName: String = "") {
        self.id = id
        self.name = name
        self.mac = mac
        self.key = key
        self.bluetoothName = bluetoothName
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case mac
        case key
        case bluetoothName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mac = try container.decode(String.self, forKey: .mac)
        key = try container.decode(String.self, forKey: .key)
        bluetoothName = try container.decodeIfPresent(String.self, forKey: .bluetoothName) ?? ""
    }
}
