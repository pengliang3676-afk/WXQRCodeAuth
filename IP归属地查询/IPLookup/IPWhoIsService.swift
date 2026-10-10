import Foundation

struct IPInfo: Decodable {
    let success: Bool?
    let ip: String?
    let type: String?
    let country: String?
    let countryCode: String?
    let region: String?
    let city: String?
    let postal: String?
    let latitude: Double?
    let longitude: Double?
    let connection: Connection?
    let timezone: Timezone?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, ip, type, country, region, city, postal, latitude, longitude, connection, timezone, message
        case countryCode = "country_code"
    }

    struct Connection: Decodable {
        let asn: Int?
        let org: String?
        let isp: String?
        let domain: String?
    }

    struct Timezone: Decodable {
        let id: String?
        let abbr: String?
        let utc: String?
    }

    var locationText: String {
        [country, region, city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var coordinatesText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}

enum IPQueryError: LocalizedError {
    case invalidIP
    case badResponse
    case lookupFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidIP:
            return "请输入有效的 IPv4 或 IPv6 地址。"
        case .badResponse:
            return "查询服务暂时无法响应，请稍后重试。"
        case .lookupFailed(let message):
            return message.isEmpty ? "没有查到这个 IP 地址。" : "查询失败：\(message)"
        }
    }
}

struct IPWhoIsService {
    func lookup(_ rawIP: String = "") async throws -> IPInfo {
        let ip = rawIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ip.isEmpty {
            let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:.")
            guard !ip.unicodeScalars.isEmpty, ip.unicodeScalars.allSatisfy(allowed.contains) else {
                throw IPQueryError.invalidIP
            }
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "ipwho.is"
        components.path = ip.isEmpty ? "/" : "/\(ip)"
        guard let url = components.url else { throw IPQueryError.badResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw IPQueryError.badResponse
        }

        let result = try JSONDecoder().decode(IPInfo.self, from: data)
        guard result.success == true, result.ip != nil else {
            throw IPQueryError.lookupFailed(result.message ?? "")
        }
        return result
    }
}
