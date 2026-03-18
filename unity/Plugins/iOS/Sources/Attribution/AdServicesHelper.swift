import Foundation
import AdServices

@objc public class AdServicesHelper: NSObject {

    @objc public static func getAttribution() -> [String: Any] {
        if #available(iOS 14.3, macOS 11.1, *) {
            do {
                let token = try AAAttribution.attributionToken()
                return ["asa_attribution_token": token]
            } catch {
                return ["asa_error": error.localizedDescription]
            }
        }
        return [:]
    }
}
