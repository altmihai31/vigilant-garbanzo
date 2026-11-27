import SwiftUI
import StashKit

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var searching = false
    @State private var showAdd = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $model.path) {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                grid
                // Fade to solid black behind the bottom buttons, down past the home indicator.
                EdgeFade(edge: .bottom)
                    .frame(height: 140)
                    .ignoresSafeArea(edges: .bottom)
                bottomBar
            }
            // The same fade at the top, behind the status bar and the filter button.
            .overlay(alignment: .top) {
                EdgeFade(edge: .top)
                    .frame(height: 70)
                    .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .topTrailing) {
                FilterMenuButton()
                    .padding(.trailing, Theme.margin)
                    .padding(.top, 2)
            }
            .overlay(alignment: .top) { ToastView() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                DetailView(itemID: id)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSheet()
        }
    }

    // MARK: Grid

    private var grid: some View {
        let list = model.visibleItems
        let header = model.filter != .all
        let cols = ItemQuery.columns(list, leadingSlots: header ? 1 : 0)
        return ScrollView {
            if list.isEmpty && !header {
                emptyState
            } else {
                HStack(alignment: .top, spacing: Theme.gap) {
                    LazyVStack(spacing: Theme.gap) {
                        if header { CollectionHeader(count: list.count) }
                        ForEach(cols.left) { card($0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    LazyVStack(spacing: Theme.gap) {
                        ForEach(cols.right) { card($0) }
                    }
                    .padding(.top, 72)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 4)
                .padding(.bottom, 150)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        // Cards scroll all the way to the bottom edge instead of stopping above the home indicator.
        .ignoresSafeArea(edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeGrid")
    }

    private func card(_ item: Item) -> some View {
        Button {
            model.path.append(item.id)
        } label: {
            CardView(item: item)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityIdentifier("card-\(item.title)")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if model.search.isEmpty {
                Image(systemName: "square.grid.2x2").font(.scaled(34)).foregroundStyle(Theme.ink3)
                Text("Nothing saved yet").font(.scaled(20, weight: .bold))
                Text("Tap + to paste a link or write a note. From Safari or YouTube, tap Share and pick Stash.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink2)
            } else {
                Text("Nothing matches \u{201C}\(model.search)\u{201D}.")
                    .foregroundStyle(Theme.ink3)
            }
        }
        .font(.scaled(15))
        .padding(.horizontal, 30)
        .padding(.top, 140)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyState")
    }

    // MARK: Bottom controls

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if searching {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.scaled(18, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    TextField("", text: $model.search, prompt: Text("Search links, notes and saved text").foregroundStyle(.white.opacity(0.55)))
                        .font(.scaled(17))
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("searchField")
                    Button {
                        model.search = ""
                        searchFocused = false
                        withAnimation(.spring(duration: 0.35)) { searching = false }
                    } label: {
                        Image(systemName: "xmark").font(.scaled(15, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close search")
                    .accessibilityIdentifier("closeSearch")
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .frame(height: 58)
                .glass(in: Capsule(), interactive: false)
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                HStack {
                    GlassIconButton(systemImage: "magnifyingglass", size: 66, iconSize: 26, label: "Search", identifier: "searchButton") {
                        withAnimation(.spring(duration: 0.35)) { searching = true }
                        searchFocused = true
                    }
                    Spacer()
                    GlassIconButton(systemImage: "plus", size: 66, iconSize: 28, label: "Add link or note", identifier: "addButton") {
                        showAdd = true
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
    }
}

/// Large title over the left column when a filter is on.
struct CollectionHeader: View {
    @EnvironmentObject var model: AppModel
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.filter.title)
                .font(.scaled(30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("collectionTitle")
            Text(subtitle).font(.scaled(13)).foregroundStyle(Theme.ink2)
            Button("Show all") {
                withAnimation { model.filter = .all }
            }
            .font(.scaled(13, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.1), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("showAll")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var subtitle: String {
        switch model.filter {
        case .readLater: return "\(count) unread. Tap a card, then Mark as read."
        case .notes: return count == 1 ? "1 note" : "\(count) notes"
        case .collection: return "\(count) saved. Stash sorted these on its own."
        case .all: return ""
        }
    }
}

/// The round glass button top right: Show, Collections and Sort, with the unread badge.
struct FilterMenuButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Menu {
            Section("Show") {
                option(.all, icon: "square.grid.2x2")
                option(.readLater, icon: "eyeglasses")
                option(.notes, icon: "text.alignleft")
            }
            Section("Collections \u{00B7} Auto") {
                ForEach(StashCollection.visible) { c in option(.collection(c), icon: c.symbol) }
            }
            Section("Sort") {
                Picker("Sort", selection: $model.sort) {
                    ForEach(ItemSortOrder.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.scaled(21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .glass(in: Circle())
                .overlay(alignment: .topTrailing) {
                    if model.unreadCount > 0 {
                        Text("\(model.unreadCount)")
                            .font(.scaled(12.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Theme.accent, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
                            .offset(x: 3, y: -3)
                            .accessibilityIdentifier("unreadBadge")
                    }
                }
        }
        .accessibilityLabel("Collections, read later and sort, \(model.unreadCount) unread")
        .accessibilityIdentifier("filterButton")
    }

    private func option(_ f: ItemFilter, icon: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { model.filter = f }
        } label: {
            Label {
                Text(f.title)
                Text("\(model.count(f))")
            } icon: {
                Image(systemName: model.filter == f ? "checkmark" : icon)
            }
        }
        .accessibilityIdentifier("filter-\(f.title)")
    }
}

/// Glass toast at the top of the screen.
struct ToastView: View {
    @EnvironmentObject var model: AppModel
    var topPadding: CGFloat = 4

    var body: some View {
        if let text = model.toastText {
            Text(text)
                .font(.scaled(14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#3A3A3C").opacity(0.85), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                .padding(.top, topPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("toast")
        }
    }
}

/// A progressive blur at the screen edge: content blurs more and darkens as it nears the top or bottom,
/// like the bars in Apple's own apps. Two materials, each masked by a gradient, make the blur ramp up.
struct EdgeFade: View {
    let edge: VerticalEdge

    private var start: UnitPoint { edge == .top ? .top : .bottom }
    private var end: UnitPoint { edge == .top ? .bottom : .top }

    private func mask(_ stops: [Gradient.Stop]) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: start, endPoint: end)
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
                .mask(mask([.init(color: .black, location: 0), .init(color: .black, location: 0.35), .init(color: .clear, location: 1)]))
            Rectangle().fill(.regularMaterial)
                .mask(mask([.init(color: .black, location: 0), .init(color: .clear, location: 0.6)]))
            mask([.init(color: .black.opacity(0.85), location: 0), .init(color: .black.opacity(0.45), location: 0.5),
                  .init(color: .black.opacity(0), location: 1)])
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
