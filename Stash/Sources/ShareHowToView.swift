import SwiftUI
import StashKit

/// "Show me": how to save from Safari or YouTube, with the real Save to Stash card as it appears there.
struct ShareHowToView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reminder: ReminderPreset? = .tonight
    @State private var saved = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.92).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Save from any app").font(.system(size: 28, weight: .heavy)).tracking(-0.5)
                        Spacer()
                        GlassIconButton(systemImage: "xmark", size: 44, iconSize: 16, label: "Close", identifier: "closeHowTo") { dismiss() }
                    }
                    step(1, "In Safari, YouTube or any app, tap the Share button.", systemImage: "square.and.arrow.up")
                    step(2, "Pick Stash in the row of apps. If it is missing, swipe to the end, tap More and turn Stash on.", systemImage: "square.grid.2x2")
                    step(3, "Choose when to read it, then tap the check. Stash writes the summary and keeps an offline copy next time you open the app.", systemImage: "checkmark.circle")
                    Text("This is the card you will see:")
                        .font(.system(size: 15)).foregroundStyle(Theme.ink2).padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 470)
            }
            ShareCardView(title: "Cacio e Pepe, the Roman Way", host: "seriouseats.com", image: DemoArt.image(named: "cacio"),
                          summary: "Three ingredients and no cream. Starchy pasta water and finely grated Pecorino make the glossy sauce.",
                          loading: false, collection: .recipes, reminder: $reminder, saved: saved,
                          onCancel: { dismiss() },
                          onSave: {
                              withAnimation { saved = true }
                              DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { saved = false } }
                          })
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("howToView")
    }

    private func step(_ n: Int, _ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.2), in: Circle())
                .foregroundStyle(Theme.accent)
            Text(text).font(.system(size: 16)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: systemImage).foregroundStyle(Theme.ink3)
        }
    }
}
