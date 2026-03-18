import Foundation

@objc public class UserDefaultsStore: NSObject {
    private let defaults: UserDefaults

    @objc public override init() {
        self.defaults = UserDefaults(suiteName: "com.vibegrowth.sdk") ?? UserDefaults.standard
        super.init()
    }

    @objc public func getString(_ key: String) -> String? {
        return defaults.string(forKey: key)
    }

    @objc public func putString(_ key: String, value: String) {
        defaults.set(value, forKey: key)
    }
}
