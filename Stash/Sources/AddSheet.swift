import SwiftUI
import StashKit

/// New Link / New Note sheet. Also edits an existing note.
struct AddSheet: View {
    var editing: Item? = nil
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    enum Kind: String { case link = "Link", note = "Note" }
    enum PreviewState {
        case idle, loading, loaded(LinkPreview), failed
    }

    @State private var kind: Kind = .link
    @State private var urlText = ""
    @State private var linkNote = ""
    @State private var noteTitle = ""
    @State private var noteBody = ""
    @State private var checklist: [ChecklistItem] = []
    @State private var preview: PreviewState = .idle
    @State private var previewTask: Task<Void, Never>?
    @State private var showHowTo = false
    @State private var hint: String?
    @FocusState private var focus: Field?

    enum Field: Hashable { case url, linkNote, title, body, check(UUID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if editing == nil { segmented }
                    if kind == .link { linkForm } else { noteForm }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.sheet.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(38)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showHowTo) { ShareHowToView() }
        .onAppear {
            if let e = editing {
                kind = .note
                noteTitle = e.title
                noteBody = e.body ?? ""
                checklist = e.checklist
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addSheet")
    }

    private var header: some View {
        HStack {
            GlassIconButton(systemImage: "xmark", size: 44, iconSize: 16, label: "Cancel", identifier: "cancelAdd") { dismiss() }
            Spacer()
            Text(editing != nil ? "Edit Note" : (kind == .link ? "New Link" : "New Note"))
                .font(.scaled(17, weight: .semibold))
                .accessibilityIdentifier("sheetTitle")
            Spacer()
            GlassIconButton(systemImage: "checkmark", size: 44, iconSize: 17, label: "Save", identifier: "saveButton", filled: true, enabled: canSave) { save() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            if let hint {
                Text(hint).font(.scaled(13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#3A3A3C"), in: Capsule())
                    .offset(y: 30)
                    .transition(.opacity)
            }
        }
        .zIndex(1)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            ForEach([Kind.link, Kind.note], id: \.self) { k in
                Button {
                    withAnimation(.spring(duration: 0.3)) { kind = k }
                } label: {
                    Text(k.rawValue)
                        .font(.scaled(15, weight: .semibold))
                        .foregroundStyle(kind == k ? Theme.ink : Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if kind == k { Capsule().fill(Color(hex: "#636366")) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("segment-\(k.rawValue)")
                .accessibilityAddTraits(kind == k ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.field, in: Capsule())
    }

    // MARK: Link

    private var linkForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "link").foregroundStyle(Theme.ink3)
                TextField("", text: $urlText, prompt: Text("Paste or type a URL").foregroundStyle(Theme.ink3))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focus, equals: .url)
                    .accessibilityIdentifier("urlField")
                    .onChange(of: urlText) { _, new in schedulePreview(for: new) }
                PasteButton(payloadType: String.self) { strings in
                    guard let s = strings.first else { return }
                    Task { @MainActor in urlText = s }
                }
                .labelStyle(.titleOnly)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(Color.white.opacity(0.14))
                .controlSize(.small)
            }
            .font(.scaled(16))
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 50)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            previewCard

            Text("YOUR NOTE").font(.scaled(13)).tracking(0.3).foregroundStyle(Theme.ink3).padding(.horizontal, 4).padding(.bottom, -8)
            TextField("", text: $linkNote, prompt: Text("Why are you saving this?").foregroundStyle(Theme.ink3), axis: .vertical)
                .lineLimit(3...6)
                .font(.scaled(16))
                .focused($focus, equals: .linkNote)
                .padding(14)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("linkNoteField")

            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up").font(.scaled(20)).foregroundStyle(Theme.accent)
                Text("Faster: tap Share in Safari or YouTube and pick Stash.")
                    .font(.scaled(14))
                    .foregroundStyle(Color(hex: "#CFE0FF"))
                Spacer(minLength: 4)
                Button("Show me") { showHowTo = true }
                    .font(.scaled(14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("showMe")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        switch preview {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(Theme.ink2)
                Text("Fetching preview\u{2026}").foregroundStyle(Theme.ink3)
            }
            .font(.scaled(14))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        case .failed:
            Text("Couldn\u{2019}t load a preview. You can still save the link; Stash will try again later.")
                .font(.scaled(14)).foregroundStyle(Theme.ink2)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        case .loaded(let p):
            VStack(alignment: .leading, spacing: 0) {
                if let data = p.imageData, let img = UIImage(data: data) {
                    Color.clear.aspectRatio(2, contentMode: .fit)
                        .overlay(Image(uiImage: img).resizable().scaledToFill())
                        .clipped()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        let host = p.link.url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
                        SiteBadge(host: host)
                        Text(host).font(.scaled(12.5)).foregroundStyle(Theme.ink3)
                    }
                    .padding(.bottom, 2)
                    Text(p.link.title).font(.scaled(17, weight: .bold)).tracking(-0.2)
                    if let s = p.link.summary {
                        SummaryLabel().padding(.top, 4)
                        Text(s).font(.scaled(14)).foregroundStyle(Theme.ink2)
                    }
                    if p.link.collection != .none {
                        CollectionPill(collection: p.link.collection, auto: true).padding(.top, 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.cardEdge))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("linkPreview")
        }
    }

    private func schedulePreview(for text: String) {
        previewTask?.cancel()
        guard let url = model.normalizedURL(text) else {
            preview = .idle
            return
        }
        preview = .loading
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            let result = await model.preview(url)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                preview = result.map { .loaded($0) } ?? .failed
            }
        }
    }

    // MARK: Note

    private var noteForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: $noteTitle, prompt: Text("Title").foregroundStyle(Theme.ink3))
                .font(.scaled(18, weight: .semibold))
                .focused($focus, equals: .title)
                .padding(14)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("noteTitleField")

            TextField("", text: $noteBody, prompt: Text("Start writing\u{2026}").foregroundStyle(Theme.ink3), axis: .vertical)
                .lineLimit(4...20)
                .font(.scaled(16))
                .focused($focus, equals: .body)
                .padding(14)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("noteBodyField")

            VStack(alignment: .leading, spacing: 10) {
                Text("CHECKLIST").font(.scaled(13)).tracking(0.3).foregroundStyle(Theme.ink3).padding(.horizontal, 4)
                ForEach($checklist) { $entry in
                    HStack(spacing: 10) {
                        Button {
                            entry.done.toggle()
                        } label: {
                            Image(systemName: entry.done ? "checkmark.circle.fill" : "circle")
                                .font(.scaled(20))
                                .foregroundStyle(entry.done ? Theme.ink3 : Theme.ink2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        TextField("Item", text: $entry.text)
                            .focused($focus, equals: .check(entry.id))
                            .submitLabel(.next)
                            .onSubmit { addChecklistItem() }
                            .strikethrough(entry.done)
                        Button {
                            checklist.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Theme.ink3)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove item")
                    }
                    .font(.scaled(16))
                }
                Button {
                    addChecklistItem()
                } label: {
                    Label("Add checklist item", systemImage: "plus.circle.fill")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addChecklistItem")
            }
            .padding(14)
            .background(Theme.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func addChecklistItem() {
        let item = ChecklistItem(text: "")
        checklist.append(item)
        focus = .check(item.id)
    }

    // MARK: Save

    /// Save stays dimmed until there is something to save (HIG: disable rather than fail).
    private var canSave: Bool {
        if kind == .link { return model.normalizedURL(urlText) != nil }
        return !noteTitle.trimmingCharacters(in: .whitespaces).isEmpty
            || !noteBody.trimmingCharacters(in: .whitespaces).isEmpty
            || checklist.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func save() {
        if kind == .link {
            guard let url = model.normalizedURL(urlText) else {
                flash("Paste a link first")
                return
            }
            var loaded: LinkPreview?
            if case .loaded(let p) = preview { loaded = p }
            previewTask?.cancel()
            model.addLink(url: url, note: linkNote.trimmingCharacters(in: .whitespacesAndNewlines), preview: loaded)
        } else {
            let hasText = !noteTitle.trimmingCharacters(in: .whitespaces).isEmpty
                || !noteBody.trimmingCharacters(in: .whitespaces).isEmpty
                || checklist.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            guard hasText else {
                flash("Write something first")
                return
            }
            model.saveNote(id: editing?.id, title: noteTitle, body: noteBody, checklist: checklist)
        }
        dismiss()
    }

    private func flash(_ text: String) {
        withAnimation { hint = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { hint = nil }
        }
    }
}
