import SwiftUI
import StashKit

/// The offline copy in a serif reading layout. Text size steps 17 to 23 pt.
struct ReaderView: View {
    let item: Item
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readerTextSize") private var textSize: Double = 19

    var body: some View {
        ZStack(alignment: .top) {
            Theme.reader.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.icloud").foregroundStyle(Theme.offline)
                        Text("Offline copy saved \(savedText). No connection needed.").foregroundStyle(Theme.ink2)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.offline.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 22)

                    Text(item.siteLabel.uppercased())
                        .font(.system(size: 13)).tracking(0.3).foregroundStyle(Theme.ink3)
                        .padding(.bottom, 8)
                    Text(item.title)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.readerInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                    Text("\(item.article?.readingMinutes ?? 1) min read")
                        .font(.system(size: 13.5)).foregroundStyle(Theme.ink2)
                        .padding(.bottom, 22)

                    if let image = model.image(for: item) {
                        Color.clear
                            .aspectRatio(16 / 10, contentMode: .fit)
                            .overlay(Image(uiImage: image).resizable().scaledToFill())
                            .clipped()
                            .padding(.horizontal, -26)
                            .padding(.bottom, 22)
                    }

                    ForEach(Array((item.article?.paragraphs ?? []).enumerated()), id: \.offset) { pair in
                        Text(pair.element)
                            .font(.system(size: textSize, design: .serif))
                            .lineSpacing(textSize * 0.5)
                            .foregroundStyle(Theme.readerInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .padding(.bottom, 18)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 70)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("readerView")

            HStack {
                GlassIconButton(systemImage: "chevron.down", size: 46, iconSize: 18, label: "Close reader", identifier: "closeReader") { dismiss() }
                Spacer()
                Button {
                    textSize = textSize >= 23 ? 17 : textSize + 2
                } label: {
                    Text("Aa").font(.system(size: 17, weight: .bold, design: .serif)).foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .glass(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Text size")
                .accessibilityValue("\(Int(textSize)) points")
                .accessibilityIdentifier("textSize")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .background(LinearGradient(stops: [.init(color: Theme.reader, location: 0.7), .init(color: Theme.reader.opacity(0), location: 1)],
                                       startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        }
        .preferredColorScheme(.dark)
    }

    private var savedText: String {
        guard let d = item.article?.savedAt else { return "" }
        let line = DateText.dateLine(for: d)
        return line == "Today" || line == "Yesterday" ? line.lowercased() : "on " + line
    }
}
