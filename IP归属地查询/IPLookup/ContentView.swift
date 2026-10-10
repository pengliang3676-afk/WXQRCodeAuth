import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputIP = ""
    @State private var result: IPInfo?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didCopy = false

    private let service = IPWhoIsService()

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    currentIPCard
                    searchCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    if let result {
                        detailsCard(result)
                    }

                    privacyNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await lookup(ip: "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.09, blue: 0.17),
                Color(red: 0.12, green: 0.075, blue: 0.16),
                Color(red: 0.055, green: 0.12, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.45, green: 0.83, blue: 1.0))
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("IP 归属地查询")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("IPv4 · IPv6")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
            }

            Spacer()

            Button {
                Task { await lookup(ip: "") }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Circle())
            }
            .disabled(isLoading)
            .accessibilityLabel("重新查询本机公网 IP")
        }
        .padding(.bottom, 2)
    }

    private var currentIPCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("IP 地址", systemImage: "globe.americas.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white.opacity(0.75))
                        .scaleEffect(0.82)
                }
            }

            Text(result?.ip ?? (isLoading ? "正在查询…" : "—"))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                if let type = result?.type, !type.isEmpty {
                    smallBadge(type)
                }
                if let countryCode = result?.countryCode, !countryCode.isEmpty {
                    smallBadge(countryCode.uppercased())
                }
                Spacer(minLength: 4)
                if let ip = result?.ip {
                    Button {
                        copy(ip)
                    } label: {
                        Label(didCopy ? "已复制" : "复制 IP", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.58, green: 0.87, blue: 1.0))
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("查询指定 IP")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.42))
                    TextField("输入 IPv4 或 IPv6 地址", text: $inputIP)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { Task { await lookup(ip: inputIP) } }
                        .accessibilityLabel("要查询的 IP 地址")
                }
                .padding(.horizontal, 13)
                .frame(height: 49)
                .background(Color.black.opacity(0.20))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    Task { await lookup(ip: inputIP) }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Label("查询", systemImage: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(minWidth: 78, minHeight: 49)
                    .background(Color(red: 0.18, green: 0.52, blue: 0.80))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)
            }

            Button {
                inputIP = ""
                Task { await lookup(ip: "") }
            } label: {
                Label("查询本机公网 IP", systemImage: "iphone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.64))
            }
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailsCard(_ info: IPInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("查询结果")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 5)

            detailRow(title: "归属地", value: info.locationText, icon: "mappin.and.ellipse")
            detailRow(title: "运营商", value: info.connection?.isp, icon: "antenna.radiowaves.left.and.right")
            detailRow(title: "网络组织", value: info.connection?.org, icon: "building.2")
            detailRow(title: "ASN", value: info.connection?.asn.map { "AS\($0)" }, icon: "number")

            let zone = [info.timezone?.id, info.timezone?.utc].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  ")
            detailRow(title: "时区", value: zone.isEmpty ? nil : zone, icon: "clock")
            detailRow(title: "坐标", value: info.coordinatesText, icon: "location")
            detailRow(title: "邮编", value: info.postal, icon: "envelope")
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 5)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailRow(title: String, value: String?, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.48, green: 0.78, blue: 0.96))
                .frame(width: 17)
                .padding(.top, 2)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.56))
                .frame(width: 64, alignment: .leading)
            Text(value?.isEmpty == false ? (value ?? "暂无数据") : "暂无数据")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(value?.isEmpty == false ? .white.opacity(0.92) : .white.opacity(0.35))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.leading, 27)
        }
    }

    private func smallBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.78))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("查询服务：ipwho.is。启动时会查询本机公网 IP；手动查询会将输入地址发送给该服务。归属地是估算信息，可能与实际位置不同。")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
            Link("开源许可 GPL-3.0 · What IP", destination: URL(string: "https://github.com/JesusChapman/What-ip")!)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.horizontal, 2)
    }

    @MainActor
    private func lookup(ip: String) async {
        isLoading = true
        errorMessage = nil
        result = nil
        didCopy = false
        do {
            result = try await service.lookup(ip)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "网络连接失败，请检查网络后重试。"
        }
        isLoading = false
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }
}

#Preview {
    ContentView()
}
