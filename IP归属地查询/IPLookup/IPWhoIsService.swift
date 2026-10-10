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

    var localizedISP: String? {
        Self.chineseProviderName(connection?.isp)
    }

    var localizedOrganization: String? {
        Self.chineseProviderName(connection?.org)
    }

    private static func chineseProviderName(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let name = value.lowercased()
        let providers: [(tokens: [String], chineseName: String)] = [
            (["china unicom", "china169", "china united network", "unicom"], "中国联通"),
            (["china telecom", "chinanet", "china tel", "chinatelecom"], "中国电信"),
            (["china mobile", "cmcc", "cmnet", "chinamobile"], "中国移动"),
            (["china broadnet", "china broadcasting network"], "中国广电"),
            (["cernet", "china education and research network"], "中国教育和科研计算机网"),
            (["cstnet", "computer network information center"], "中国科技网"),
            (["chunghwa telecom"], "中华电信"),
            (["taiwan mobile"], "台湾大哥大"),
            (["far eastone", "fareastone"], "远传电信"),
            (["ntt docomo", "docomo"], "日本NTT Docomo"),
            (["kddi"], "日本KDDI"),
            (["softbank"], "日本软银"),
            (["sk telecom"], "韩国SK电讯"),
            (["kt corporation", "korea telecom"], "韩国KT电信"),
            (["lg uplus", "lg telecom"], "韩国LG U+"),
            (["singtel", "singapore telecommunications"], "新加坡电信"),
            (["starhub"], "新加坡星和电信"),
            (["telstra"], "澳大利亚Telstra"),
            (["deutsche telekom"], "德国电信"),
            (["telefonica"], "西班牙电信"),
            (["vodafone"], "沃达丰"),
            (["comcast"], "美国康卡斯特"),
            (["at&t", "att services"], "美国AT&T"),
            (["verizon"], "美国威瑞森"),
            (["t-mobile"], "美国T-Mobile"),
            (["google llc"], "谷歌网络"),
            (["amazon.com", "amazon data services"], "亚马逊云网络"),
            (["microsoft corporation", "microsoft azure"], "微软网络")
        ]

        return providers.first(where: { provider in
            provider.tokens.contains(where: name.contains)
        })?.chineseName ?? value
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
        components.queryItems = [URLQueryItem(name: "lang", value: "zh-CN")]
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
