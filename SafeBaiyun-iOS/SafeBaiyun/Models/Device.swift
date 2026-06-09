import Foundation

struct Device: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var mac: String
    var key: String
    
    init(id: String = UUID().uuidString, name: String, mac: String, key: String) {
        self.id = id
        self.name = name
        self.mac = mac
        self.key = key
    }
}