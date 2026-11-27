import SwiftUI
import MapKit
import StashKit

struct DetailView: View {
    let itemID: UUID
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showReader = false
    @State private var editingNote = false
    @State private var noteDraft = ""
    @State private var addingTag = false
    @State private var tagDraft = ""
    @State private var editingItem = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Theme.detail.ignoresSafeArea()
                if let item = model.item(itemID) {
                    ScrollView {
                        content(item, safeTop: geo.safeAreaInsets.top)
                    }
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("detailView")
                    LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: geo.safeAreaInsets.top + 72)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                    topBar(item)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { ToastView(topPadding: 66) }
        .fullScreenCover(isPresented: $showReader) {
            if let item = model.item(itemID) { ReaderView(item: item) }
        }
        .sheet(isPresented: $editingItem) {
            if let item = model.item(itemID) { AddSheet(editing: item) }
        }
        .alert("Add tag", isPresented: $addingTag) {
            TextField("Tag", text: $tagDraft)
            Button("Add") {
                model.addTag(itemID, tagDraft)
                tagDraft = ""
            }
            Button("Cancel", role: .cancel) { tagDraft = "" }
        }
    }

    // MARK: Top bar

    private func topBar(_ item: Item) -> some View {
        HStack {
            GlassIconButton(systemImage: "chevron.left", size: 52, iconSize: 20, label: "Back", identifier: "backButton") { dismiss() }
            Spacer()
            HStack(spacing: 10) {
                if let url = item.url {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .glass(in: Circle())
                    }
                    .accessibilityLabel("Share")
                }
                Menu {
                    if item.kind == .note {
                        Button { editingItem = true } label: { Label("Edit note", systemImage: "pencil") }
                    } else {
                        if item.isUnread {
                            Button { model.markRead(itemID) } label: { Label("Mark as read", systemImage: "checkmark.circle") }
                        } else {
                            Button { model.markUnread(itemID) } label: { Label("Mark unread", systemImage: "circle.fill") }
                        }
                        if let url = item.url {
                            Button { UIPasteboard.general.url = url; model.showToast("Link copied") } label: { Label("Copy link", systemImage: "doc.on.doc") }
                        }
                    }
                    Menu {
                        collectionChoices(item)
                    } label: { Label("Move to collection", systemImage: "folder") }
                    Divider()
                    Button(role: .destructive) {
                        dismiss()
                        model.delete(itemID)
                    } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .glass(in: Circle())
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("moreButton")
            }
        }
        .padding(.horizontal, Theme.margin)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ item: Item, safeTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.kind == .link, let image = model.image(for: item) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom).frame(height: 160)
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 120)
                    }
                    .padding(.bottom, 22)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(height: safeTop + 76)
            }

            VStack(alignment: .leading, spacing: 0) {
                if item.kind == .link { linkBody(item) } else { noteBody(item) }
                section("Collection and tags") { collectionAndTags(item) }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 64)
        }
    }

    private func linkBody(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                SiteBadge(host: item.siteLabel, size: 20)
                Text("\(item.siteLabel) \u{00B7} \(DateText.saved(item.createdAt))")
                    .lineLimit(1)
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.ink2)
            .padding(.bottom, 12)

            Text(item.title)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
                .accessibilityIdentifier("detailTitle")

            if item.processingState == .pending && item.summary == nil {
                SummaryLabel(text: "Summarizing\u{2026}").padding(.bottom, 6)
                ShimmerLines(lines: 3).padding(.bottom, 22)
            } else if let summary = item.summary {
                SummaryLabel().padding(.bottom, 6)
                Text(summary)
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "#E5E5EA"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 22)
                    .accessibilityIdentifier("detailSummary")
            }

            FlowLayout(spacing: 10) {
                if let url = item.url {
                    Button {
                        model.markRead(itemID, toast: false)
                        openURL(url)
                    } label: {
                        pill("Open in Safari", systemImage: "arrow.up.right", trailingIcon: true, white: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("openInSafari")
                }
                if item.article != nil {
                    Button {
                        showReader = true
                        model.markRead(itemID, toast: false)
                    } label: {
                        pill("Read offline", systemImage: "book")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("readOffline")
                }
            }

            section("Read later") { readLater(item) }

            if let place = item.place {
                section("Location") { location(place, item: item) }
            }

            if let article = item.article {
                section("Offline copy") {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.icloud").foregroundStyle(Theme.offline)
                        Text("Article text saved on \(DateText.numeric(article.savedAt)) \u{00B7} \(article.readingMinutes) min read. It still opens if the page changes or goes away.")
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 13.5))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("offlineCopy")
                }
            } else if item.processingState == .failed {
                section("Offline copy") {
                    Text("Stash could not fetch this page. It will try again next time you open the app.")
                        .font(.system(size: 13.5)).foregroundStyle(Theme.ink2)
                }
            }

            section("Your note") { noteEditor(item) }
        }
    }

    private func noteBody(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                Text("Note \u{00B7} \(DateText.dateLine(for: item.createdAt))")
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.ink2)
            .padding(.bottom, 12)

            Text(item.title)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
                .accessibilityIdentifier("detailTitle")

            if let body = item.body {
                Text(body)
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "#E5E5EA"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            }
            if !item.checklist.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(item.checklist) { entry in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { model.toggleChecklist(itemID, entry.id) }
                        } label: {
                            ChecklistRow(entry: entry, size: 20, font: 17)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("check-\(entry.text)")
                        .accessibilityValue(entry.done ? "done" : "not done")
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.ink3)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
        .padding(.top, 28)
    }

    private func pill(_ title: String, systemImage: String, trailingIcon: Bool = false, white: Bool = false) -> some View {
        HStack(spacing: 8) {
            if !trailingIcon { Image(systemName: systemImage) }
            Text(title)
            if trailingIcon { Image(systemName: systemImage) }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(white ? Color.black : Theme.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(white ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Color.white.opacity(0.1)), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(white ? 0 : 0.14)))
    }

    private func readLater(_ item: Item) -> some View {
        let selected = ReminderPreset.matching(item.remindAt)
        let status: String = {
            if let r = item.remindAt, item.hasUpcomingReminder() { return "Reminder: " + DateText.reminder(r) }
            return item.isUnread ? "In your Read later list" : "You read this"
        }()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.reminder)
                    .frame(width: 34, height: 34)
                    .background(Theme.reminder.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.isUnread ? "Unread" : "Read").font(.system(size: 15.5, weight: .semibold))
                    Text(status).font(.system(size: 13)).foregroundStyle(Theme.ink2)
                        .accessibilityIdentifier("readLaterStatus")
                }
                Spacer()
                Button(item.isUnread ? "Mark as read" : "Mark unread") {
                    if item.isUnread { model.markRead(itemID) } else { model.markUnread(itemID) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier(item.isUnread ? "markRead" : "markUnread")
            }
            HStack(spacing: 8) {
                ForEach(ReminderPreset.allCases) { p in
                    ChipButton(title: p.label, selected: selected == p && item.hasUpcomingReminder(), selectedFill: Theme.reminder) {
                        model.toggleReminder(itemID, preset: p)
                    }
                    .accessibilityIdentifier("remind-\(p.label)")
                }
            }
        }
        .padding(14)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }

    @ViewBuilder
    private func location(_ place: Place, item: Item) -> some View {
        Group {
            if let lat = place.latitude, let lon = place.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                Map(initialPosition: .region(MKCoordinateRegion(center: coord, latitudinalMeters: 1800, longitudinalMeters: 1800)),
                    interactionModes: []) {
                    Marker(place.name, coordinate: coord).tint(Theme.pin)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            } else {
                ZStack {
                    Theme.sheet
                    Label("Finding it on the map\u{2026}", systemImage: "map").foregroundStyle(Theme.ink3)
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .accessibilityIdentifier("placeMap")

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.system(size: 16, weight: .semibold))
                if let a = place.address ?? place.city {
                    Text(a).font(.system(size: 13.5)).foregroundStyle(Theme.ink2)
                }
            }
            Spacer()
            Button {
                openURL(place.mapsURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                    Text("Open in Maps")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openInMaps")
        }
        .padding(.top, 2)
        if item.collection == .places {
            Text("Found in the article, so Stash put this in Places.").font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
        }
    }

    @ViewBuilder
    private func noteEditor(_ item: Item) -> some View {
        if editingNote {
            VStack(alignment: .trailing, spacing: 8) {
                TextField("Why are you saving this?", text: $noteDraft, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(2...8)
                    .padding(12)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($noteFocused)
                    .accessibilityIdentifier("noteField")
                Button("Done") {
                    let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    model.update(itemID) { $0.note = text.isEmpty ? nil : text }
                    editingNote = false
                }
                .font(.system(size: 15, weight: .semibold))
                .accessibilityIdentifier("noteDone")
            }
        } else {
            Button {
                noteDraft = item.note ?? ""
                editingNote = true
                noteFocused = true
            } label: {
                Text(item.note ?? "Add a note to remember why you saved this.")
                    .font(.system(size: 16))
                    .lineSpacing(3)
                    .foregroundStyle(item.note == nil ? Theme.ink3 : Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("noteText")
        }
    }

    @ViewBuilder
    private func collectionChoices(_ item: Item) -> some View {
        ForEach(StashCollection.visible + [.none]) { c in
            Button {
                model.setCollection(itemID, c)
            } label: {
                Label(c.name, systemImage: item.collection == c ? "checkmark" : c.symbol)
            }
        }
    }

    private func collectionAndTags(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                Menu {
                    collectionChoices(item)
                } label: {
                    if item.collection != .none {
                        CollectionPill(collection: item.collection)
                    } else {
                        tagView("No collection", systemImage: "folder")
                    }
                }
                .accessibilityIdentifier("collectionPill")
                ForEach(item.tags, id: \.self) { tag in
                    Menu {
                        Button(role: .destructive) { model.removeTag(itemID, tag) } label: { Label("Remove \u{201C}\(tag)\u{201D}", systemImage: "minus.circle") }
                    } label: {
                        tagView(tag)
                    }
                }
                Button { addingTag = true } label: { tagView("Add tag", systemImage: "plus") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addTag")
            }
            if item.collection != .none {
                Text(item.collectionIsManual ? "You picked this collection." : "Sorted automatically from what \(item.kind == .note ? "the note" : "the page") is about.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
            }
        }
    }

    private func tagView(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .bold)) }
            Text(text)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Theme.field, in: Capsule())
        .foregroundStyle(Color(hex: "#D1D1D6"))
    }
}
