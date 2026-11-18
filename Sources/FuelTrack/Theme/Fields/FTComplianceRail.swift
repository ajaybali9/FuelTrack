import SwiftUI

struct FTComplianceRail: View {
    var motStatus: String
    var motOK: Bool
    var taxStatus: String
    var taxOK: Bool
    var insuranceStatus: String
    var insuranceOK: Bool
    var isRefreshing: Bool
    var canRefresh: Bool
    var message: String?
    var onRefresh: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLIANCE")
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                chip(title: "MOT", status: motStatus, ok: motOK)
                chip(title: "Tax", status: taxStatus, ok: taxOK)
                chip(title: "Ins.", status: insuranceStatus, ok: insuranceOK)
            }

            Button(action: onRefresh) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Refresh MOT & tax from DVLA")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(cornerRadius: FuelTrackTokens.chipRadius, style: .continuous)
                        .fill(GlassTheme.accent)
                }
                .scaleEffect(pulse && !reduceMotion ? 1.02 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing || !canRefresh)
            .opacity(canRefresh ? 1 : 0.5)
            .accessibilityLabel("Refresh MOT and tax from DVLA")

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: isRefreshing) { was, now in
            if was && !now && message != nil {
                guard !reduceMotion else { return }
                withAnimation(.smooth(duration: 0.25)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.smooth(duration: 0.25)) { pulse = false }
                }
            }
        }
    }

    private func chip(title: String, status: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FuelTrackTokens.labelFont())
                .foregroundStyle(.secondary)
            Text(status.isEmpty ? "—" : status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ok ? GlassTheme.success : GlassTheme.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(status.isEmpty ? "unknown" : status)")
    }
}
