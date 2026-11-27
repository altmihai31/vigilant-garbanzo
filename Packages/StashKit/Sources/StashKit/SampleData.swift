import Foundation

/// The mockup's sample items, used for demo mode, UI tests and previews.
public enum SampleData {
    public static func items(now: Date = Date(), calendar: Calendar = .current) -> [Item] {
        func ago(days: Int, minutes: Int = 0) -> Date {
            let d = calendar.date(byAdding: .day, value: -days, to: now)!
            return d.addingTimeInterval(TimeInterval(-minutes * 60))
        }
        func art(_ ps: [String], days: Int) -> Article { Article(paragraphs: ps, savedAt: ago(days: days)) }
        let tonight = ReminderPreset.tonight.date(from: now, calendar: calendar)
        let weekend = ReminderPreset.weekend.date(from: now, calendar: calendar)

        return [
            Item(kind: .link, createdAt: ago(days: 0, minutes: 5), title: "Top Hotels on the Amalfi Coast",
                 summary: "Le Sirenuse, Santa Caterina and Il San Pietro have dramatic cliffside views.", summarySource: .onDevice,
                 url: URL(string: "https://www.cntraveler.com/gallery/best-hotels-amalfi-coast"), siteName: "Condé Nast Traveler",
                 collection: .places, tags: ["Italy", "June trip"], isUnread: true, remindAt: tonight,
                 place: Place(name: "Le Sirenuse", address: "Via Cristoforo Colombo 30, Positano", city: "Positano, Italy",
                              latitude: 40.6281, longitude: 14.4850),
                 article: art(["Positano, Amalfi and Ravello each have a handful of hotels that justify the trip on their own. Le Sirenuse is the classic: a converted family villa with a red façade, a lemon-tree terrace and the best view of Positano\u{2019}s dome.",
                               "Hotel Santa Caterina, just outside Amalfi town, has a lift cut into the cliff that drops you at a private lido. Il San Pietro is built into the rock face east of Positano, with its own beach and tennis court far below.",
                               "Book early for June. The terraces fill first, and the cheaper rooms facing the hill sell out by March."], days: 0),
                 note: "For the June trip. Santa Caterina has the sea elevator to the beach club.", demoArt: "coast"),
            Item(kind: .note, createdAt: ago(days: 0, minutes: 30), title: "Gift ideas for Mom",
                 checklist: [ChecklistItem(text: "Silk scarf from Hermès"), ChecklistItem(text: "Cooking class in Bucharest", done: true),
                             ChecklistItem(text: "Framed photo from Sinaia")], collection: .shopping),
            Item(kind: .link, createdAt: ago(days: 0, minutes: 90), title: "Sony WH-1000XM6 Review",
                 summary: "The best noise cancelling you can buy, with a lighter folding design and 30-hour battery.", summarySource: .onDevice,
                 url: URL(string: "https://www.theverge.com/reviews/sony-wh-1000xm6-review"), siteName: "The Verge",
                 collection: .shopping, isUnread: true,
                 article: art(["Sony\u{2019}s sixth-generation flagship folds again, which fixes the biggest complaint about the XM5. Noise cancelling is a step ahead of everything else we tested, especially on low engine rumble.",
                               "Battery life stays at 30 hours with ANC on. Call quality improves thanks to more beamforming microphones, though wind noise can still creep in outdoors."], days: 0),
                 demoArt: "phones"),
            Item(kind: .link, createdAt: ago(days: 1, minutes: 10), title: "Where to Eat Near Apple Park in Cupertino",
                 summary: "Locals love BJ\u{2019}s Restaurant & Brewhouse, Ramen Nagi and Ettan.", summarySource: .onDevice,
                 url: URL(string: "https://sf.eater.com/maps/best-restaurants-cupertino-apple-park"), siteName: "Eater SF",
                 collection: .places, tags: ["California"],
                 place: Place(name: "Ramen Nagi", address: "Valley Fair, Santa Clara, CA", city: "Santa Clara, CA",
                              latitude: 37.3249, longitude: -121.9446),
                 article: art(["Cupertino\u{2019}s food scene is more than office cafeterias. Ramen Nagi at Valley Fair draws lines for its customisable tonkotsu, with the black garlic Kuro-O the order to get.",
                               "Ettan in Palo Alto does modern Indian with a cocktail list to match, and BJ\u{2019}s is the easy group dinner a short drive from the Apple Park visitor center."], days: 1),
                 demoArt: "ramen"),
            Item(kind: .link, createdAt: ago(days: 1, minutes: 60), title: "Apple\u{2019}s Priorities for Upcoming Foldable iPhone",
                 summary: "Apple is planning industry-leading durability and an iPad-like app experience.", summarySource: .onDevice,
                 url: URL(string: "https://www.macrumors.com/2026/11/25/foldable-iphone-priorities/"), siteName: "MacRumors",
                 collection: .reading, tags: ["iPhone"], isUnread: true,
                 article: art(["Apple\u{2019}s first foldable is said to focus on a nearly invisible crease and a hinge built to last years of daily folding.",
                               "Unfolded, the inner display is expected to run apps in an iPad-like layout, with a side-by-side view for two apps at once."], days: 1)),
            Item(kind: .note, createdAt: ago(days: 3), title: "App idea: share sheet first",
                 body: "Saving should take one tap from Safari. Preview loads in the background, tags are optional, and the card lands at the top of the grid.",
                 tags: ["Ideas"]),
            Item(kind: .link, createdAt: ago(days: 4), title: "Sheet-Pan Gnocchi with Crispy Kale",
                 summary: "Store-bought gnocchi roasts crisp in 25 minutes with cherry tomatoes and kale.", summarySource: .onDevice,
                 url: URL(string: "https://www.bonappetit.com/recipe/sheet-pan-gnocchi"), siteName: "Bon Appétit",
                 collection: .recipes, tags: ["Weeknight"],
                 article: art(["Skip the boiling. Shelf-stable gnocchi go straight onto a hot sheet pan with olive oil and get crisp outside and soft inside.",
                               "Add kale and cherry tomatoes for the last ten minutes, then finish with lemon zest and Parmesan. Dinner in 25 minutes and one pan to wash."], days: 4),
                 demoArt: "gnocchi"),
            Item(kind: .link, createdAt: ago(days: 5), title: "Best Sushi Spots in Tokyo for First-Time Visitors",
                 summary: "Sukiyabashi Jiro, Sushi Saito and Umi top the list.", summarySource: .onDevice,
                 url: URL(string: "https://www.timeout.com/tokyo/restaurants/best-sushi-in-tokyo"), siteName: "Time Out",
                 collection: .places, tags: ["Japan"],
                 place: Place(name: "Sushi Saito", address: "Minato City, Tokyo", city: "Tokyo, Japan", latitude: 35.6655, longitude: 139.7393),
                 article: art(["Tokyo has more great sushi counters than any city on earth, and booking is half the battle. Sushi Saito and Sukiyabashi Jiro need a hotel concierge and months of notice.",
                               "For something easier, Umi in Aoyama takes online reservations and serves a lunch omakase that rivals the famous names for a third of the price."], days: 5),
                 demoArt: "sushi"),
            Item(kind: .link, createdAt: ago(days: 7), title: "Applying Liquid Glass to custom views",
                 summary: "Use glassEffect() and GlassEffectContainer to morph controls together.", summarySource: .onDevice,
                 url: URL(string: "https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views"),
                 siteName: "Apple Developer", collection: .reading, tags: ["SwiftUI"], isUnread: true, remindAt: weekend,
                 article: art(["Apply glassEffect() to a view to give it the Liquid Glass material. Wrap several glass views in a GlassEffectContainer so they blend and morph into each other as they move.",
                               "Use glassEffectID with a namespace to animate a control from one shape to another, such as a button growing into a toolbar."], days: 7),
                 demoArt: "code"),
            Item(kind: .link, createdAt: ago(days: 9), title: "Porsche Taycan Features Worth Paying Extra For",
                 summary: "Rear-axle steering and the passenger display top the list, while the sport chrono pack is optional.", summarySource: .onDevice,
                 url: URL(string: "https://www.caranddriver.com/porsche/taycan-options"), siteName: "Car and Driver",
                 collection: .reading, tags: ["Cars"],
                 article: art(["The Taycan\u{2019}s options list is long. Rear-axle steering is the one we would not skip: it shrinks the turning circle and calms the car at speed.",
                               "The passenger display is a fun extra on long trips. The sport chrono pack adds launch control drama but little everyday value."], days: 9),
                 demoArt: "car"),
            Item(kind: .link, createdAt: ago(days: 12), title: "Top 25 NBA Stars Under 25 Ranked in 2026",
                 summary: "Victor Wembanyama leads the next generation, followed by Anthony Edwards.", summarySource: .onDevice,
                 url: URL(string: "https://www.theringer.com/nba/top-25-under-25-2026"), siteName: "The Ringer",
                 collection: .reading, tags: ["NBA"],
                 article: art(["Victor Wembanyama is the easy number one, a defensive force who now runs the offense too. Anthony Edwards follows as the league\u{2019}s most explosive young scorer.",
                               "The middle of the list is where the arguments start, with a wave of 21-year-olds pushing for All-Star spots."], days: 12),
                 demoArt: "court"),
            Item(kind: .note, createdAt: ago(days: 15), title: "Hike checklist",
                 checklist: [ChecklistItem(text: "Headlamp", done: true), ChecklistItem(text: "Rain shell", done: true),
                             ChecklistItem(text: "2 L water"), ChecklistItem(text: "Offline map")], tags: ["Hiking"]),
            Item(kind: .link, createdAt: ago(days: 17), title: "The Quiet Trails of the Dolomites",
                 summary: "Skip Seceda at noon. Go to Val di Funes at sunrise instead.", summarySource: .onDevice,
                 url: URL(string: "https://www.outsideonline.com/adventure-travel/dolomites-quiet-trails"), siteName: "Outside",
                 collection: .places, tags: ["Hiking", "Italy"],
                 place: Place(name: "Val di Funes", address: "South Tyrol, Italy", city: "South Tyrol, Italy", latitude: 46.6420, longitude: 11.6800),
                 article: art(["The Dolomites\u{2019} famous viewpoints are packed by mid-morning. Val di Funes, with the Odle peaks behind the church of St. Johann, is calm at sunrise and a short drive from Bressanone.",
                               "The Adolf Munkel trail runs under the Odle walls for three easy hours, with a hut lunch at Geisleralm halfway."], days: 17),
                 demoArt: "mountain")
        ]
    }

    /// Canned pages for demo mode and tests, keyed by host.
    public static let lisbonURL = URL(string: "https://www.monocle.com/travel/lisbon-city-guide")!

    public static let lisbonHTML = """
    <!doctype html><html><head>
    <title>Lisbon City Guide | Monocle</title>
    <meta property="og:title" content="Lisbon City Guide: Where to Stay, Eat and Shop">
    <meta property="og:description" content="Tiled cafés in Príncipe Real, rooftop bars in Graça and a weekend plan for the Portuguese capital.">
    <meta property="og:site_name" content="Monocle">
    <meta property="og:image" content="demo://lisbon">
    <script type="application/ld+json">{"@context":"https://schema.org","@type":"TouristDestination","name":"Príncipe Real","address":{"@type":"PostalAddress","addressLocality":"Lisbon","addressCountry":"Portugal"},"geo":{"latitude":38.7167,"longitude":-9.1486}}</script>
    </head><body><nav><p>Subscribe to our newsletter for the best of Monocle every week.</p></nav>
    <article><h1>Lisbon City Guide</h1>
    <p>Lisbon rewards slow weekends. Start in Príncipe Real, where the garden square is lined with concept stores, tiled cafés and the city&rsquo;s best bookshop.</p>
    <p>Walk down to Chiado for lunch, then take the 28 tram up to Graça for sunset from the miradouro. Dinner is at a tasca in Alfama, where fado drifts out of every second doorway.</p>
    </article><footer><p>All rights reserved. Monocle 2026, all of it, every word and picture.</p></footer></body></html>
    """

    public static let cacioURL = URL(string: "https://www.seriouseats.com/cacio-e-pepe-recipe")!

    public static let cacioHTML = """
    <html><head><meta property="og:title" content="Cacio e Pepe, the Roman Way">
    <meta name="description" content="Three ingredients and no cream. Starchy pasta water and finely grated Pecorino make the glossy sauce.">
    <meta property="og:image" content="demo://cacio"><meta property="og:site_name" content="Serious Eats">
    <script type="application/ld+json">[{"@type":"Recipe","name":"Cacio e Pepe"}]</script></head>
    <body><article>
    <p>Three ingredients, one pan and no cream. The trick is starchy pasta water and cheese grated as fine as dust, whisked off the heat so it turns into a glossy sauce instead of clumps.</p>
    <p>Toast the pepper first. Cook the spaghetti in half the usual water so it stays cloudy with starch, then build the sauce in the pan with Pecorino Romano and a splash of that water.</p>
    <p>If the sauce tightens, add more water a spoonful at a time and keep tossing. Serve right away, on warm plates.</p>
    </article></body></html>
    """

    /// Offline loader for demo mode and UI tests: known pages for the sample URLs, a generic page otherwise.
    public struct DemoLoader: PageLoading {
        public init() {}
        public func load(_ url: URL) async throws -> (html: String, finalURL: URL) {
            try await Task.sleep(nanoseconds: 600_000_000)
            let host = (url.host ?? "").lowercased()
            if host.hasSuffix("monocle.com") { return (SampleData.lisbonHTML, url) }
            if host.hasSuffix("seriouseats.com") { return (SampleData.cacioHTML, url) }
            let name = host.replacingOccurrences(of: "www.", with: "").split(separator: ".").first.map { $0.capitalized } ?? "Example"
            let html = """
            <html><head><title>\(name) page</title><meta property="og:image" content="demo://mountain">
            <meta name="description" content="The summary is written from the page text once Stash fetches the real page."></head>
            <body><p>This is where the saved article text appears once Stash has fetched the real page from the web.</p></body></html>
            """
            return (html, url)
        }
    }
}
