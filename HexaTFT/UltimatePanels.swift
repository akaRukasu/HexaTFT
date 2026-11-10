import SwiftUI

struct FeatureBanner: View {
    let eyebrow: String
    let title: String
    let detail: String
    let icon: String
    var accent: Color = hexaGold

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(eyebrow, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(accent)
            Text(title).font(.largeTitle.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 112, weight: .thin))
                .foregroundStyle(accent.opacity(0.13))
                .padding(12).accessibilityHidden(true)
        }
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [accent.opacity(0.17), hexaNavy], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(accent.opacity(0.24)))
        .accessibilityElement(children: .combine)
    }
}

struct DashboardMetric: View {
    let title: String
    let value: String
    var accent: Color = hexaGold

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(accent)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
