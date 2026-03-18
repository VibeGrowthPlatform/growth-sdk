import Foundation
import AdSupport
import UIKit

@objc public class UserIdentityManager: NSObject {
    private static let deviceIdKey = "vibegrowth_device_id"
    private static let userIdKey = "vibegrowth_user_id"

    private let store: UserDefaultsStore

    @objc public init(store: UserDefaultsStore) {
        self.store = store
        super.init()
    }

    @objc public func getOrCreateDeviceId() -> String {
        if let existing = store.getString(UserIdentityManager.deviceIdKey) {
            return existing
        }

        let deviceId = resolveDeviceId()
        store.putString(UserIdentityManager.deviceIdKey, value: deviceId)
        return deviceId
    }

    private func resolveDeviceId() -> String {
        let zeroUUID = "00000000-0000-0000-0000-000000000000"

        // 1. Try ADID (IDFA)
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        if idfa != zeroUUID {
            return idfa
        }

        // 2. Try IDFV
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }

        // 3. Fallback: random UUID
        return UUID().uuidString
    }

    @objc public func setUserId(_ userId: String) {
        store.putString(UserIdentityManager.userIdKey, value: userId)
    }

    @objc public func getUserId() -> String? {
        return store.getString(UserIdentityManager.userIdKey)
    }
}
