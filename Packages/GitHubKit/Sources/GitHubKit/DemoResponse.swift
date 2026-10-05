import Foundation

extension APIResponse {
    public static func demo(_ json: JSON) -> APIResponse {
        APIResponse(data: (try? json.encoded()) ?? Data(), headers: [:], status: 200, isOffline: false)
    }
}
