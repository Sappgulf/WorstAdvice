import SwiftUI

#if targetEnvironment(macCatalyst)
import AppKit

// MARK: - Mac Catalyst Support

class MacWindowManager {
    static let shared = MacWindowManager()
    
    private init() {}
    
    func setupMacSpecificFeatures() {
        #if targetEnvironment(macCatalyst)
        // Configure toolbar
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let titlebar = scene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        }
        #endif
    }
    
    func enableMultiWindow() {
        #if targetEnvironment(macCatalyst)
        UIApplication.shared.supportsMultipleScenes = true
        #endif
    }
}

// MARK: - Mac Menu Bar

extension NSToolbar {
    static func configureBadviceToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "BadviceToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = true
        return toolbar
    }
}

// MARK: - Mac Touch Bar Support

@available(macCatalyst 13.0, *)
class TouchBarProvider: NSObject {
    static let shared = TouchBarProvider()
    
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.defaultItemIdentifiers = [
            .generateAdvice,
            .favorites,
            .statistics
        ]
        return touchBar
    }
}

extension NSTouchBarItem.Identifier {
    static let generateAdvice = NSTouchBarItem.Identifier("com.badvice.generate")
    static let favorites = NSTouchBarItem.Identifier("com.badvice.favorites")
    static let statistics = NSTouchBarItem.Identifier("com.badvice.stats")
}

// MARK: - Mac Keyboard Shortcuts

struct MacKeyboardShortcuts: View {
    var body: some View {
        Color.clear
            .keyboardShortcut("n", modifiers: [.command])
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .keyboardShortcut("s", modifiers: [.command, .option])
    }
}

#endif

// MARK: - iPad Multi-Window Support

struct SceneConfiguration {
    static func configure() -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: .windowApplication)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        #if os(iOS)
        // iPad multi-window configuration
        if UIDevice.current.userInterfaceIdiom == .pad {
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 800)
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1400, height: 1200)
        }
        #endif
        
        // Handle user activities
        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
            configure(window: window, with: userActivity)
        }
    }
    
    func configure(window: UIWindow?, with activity: NSUserActivity) {
        // Restore state from user activity
        if let restoration = HandoffManager.shared.restoreState(from: activity) {
            // Navigate based on restoration result
        }
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
}

// MARK: - iPad Split View Support

struct iPadSplitView: View {
    @State private var selectedTab: AppTab = .generate
    @Bindable var session: AppSessionViewModel
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle("Badvice")
        } detail: {
            // Detail view
            tabContent(for: selectedTab)
        }
        #if os(iOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }
    
    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .generate:
            GenerateTabView(viewModel: session.generate, settings: session.settings, onDataChanged: {})
        case .quotes:
            QuotesTabView(viewModel: session.quotes, settings: session.settings)
        case .favorites:
            FavoritesTabView(viewModel: session.favorites, settings: session.settings)
        case .history:
            HistoryTabView(
                viewModel: session.history,
                settings: session.settings,
                onUseRecord: { _ in },
                onDataChanged: {}
            )
        case .settings:
            SettingsTabView(
                viewModel: session.settings,
                generateViewModel: session.generate,
                quotesViewModel: session.quotes,
                social: session.social,
                achievementsManager: session.achievements
            )
        }
    }
}

// MARK: - iPad Drag and Drop Enhanced

struct iPadDragDropEnhancement: ViewModifier {
    let advice: AdviceRecord
    
    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .onDrag {
                let itemProvider = NSItemProvider()
                
                // Add multiple representations
                itemProvider.registerDataRepresentation(
                    forTypeIdentifier: "public.plain-text",
                    visibility: .all
                ) { completion in
                    let data = self.advice.adviceLine.data(using: .utf8)
                    completion(data, nil)
                    return nil
                }
                
                // Add image representation
                if let image = self.generateShareCard() {
                    itemProvider.registerDataRepresentation(
                        forTypeIdentifier: "public.image",
                        visibility: .all
                    ) { completion in
                        completion(image.pngData(), nil)
                        return nil
                    }
                }
                
                return itemProvider
            }
            .dropDestination(for: String.self) { items, location in
                // Handle dropped text
                return true
            }
            #else
            .id(advice.id)
            #endif
    }
    
    private func generateShareCard() -> UIImage? {
        let content = ShareCardContent(
            category: advice.category,
            tone: advice.tone,
            adviceLine: advice.adviceLine,
            rationaleLine: advice.rationaleLine,
            includeDisclaimer: true,
            template: .gradient,
            aspectRatio: .square
        )
        return ShareCardRenderer.render(content: content)
    }
}

extension View {
    func iPadDragDrop(advice: AdviceRecord) -> some View {
        modifier(iPadDragDropEnhancement(advice: advice))
    }
}

// MARK: - Mac Catalyst Window Management

#if targetEnvironment(macCatalyst)

class MacWindowController {
    static let shared = MacWindowController()
    
    private init() {}
    
    func newWindow(with activity: NSUserActivity? = nil) {
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil,
            errorHandler: nil
        )
    }
    
    func closeCurrentWindow() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
    }
}

#endif

// MARK: - iPad Pencil Support

struct iPadPencilSupport: ViewModifier {
    @State private var isDrawing = false
    @State private var drawings: [PKDrawing] = []
    
    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .overlay {
                if isDrawing {
                    PencilCanvasView(drawings: $drawings)
                }
            }
            #endif
    }
}

#if os(iOS)
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawings: [PKDrawing]
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.tool = PKInkingTool(.pen, color: .orange, width: 3)
        canvas.drawingPolicy = .anyInput
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
#endif

// MARK: - iPad Stage Manager Support

struct StageManagerOptimized: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    func body(content: Content) -> some View {
        content
            .onChange(of: horizontalSizeClass) { _, newValue in
                adaptLayout(horizontal: newValue)
            }
            .onChange(of: verticalSizeClass) { _, newValue in
                adaptLayout(vertical: newValue)
            }
    }
    
    private func adaptLayout(horizontal: UserInterfaceSizeClass? = nil, vertical: UserInterfaceSizeClass? = nil) {
        // Adjust layout based on window size in Stage Manager
        if horizontal == .compact {
            // Single column layout
        } else {
            // Multi-column layout
        }
    }
}

extension View {
    func stageManagerOptimized() -> some View {
        modifier(StageManagerOptimized())
    }
}

// MARK: - Mac Menu Bar App (Catalyst)

#if targetEnvironment(macCatalyst)

class MacMenuBarManager {
    static let shared = MacMenuBarManager()
    
    func setupMenuBar() {
        let mainMenu = UIMenu(title: "", options: .displayInline, children: [
            UICommand(
                title: "Generate Advice",
                action: #selector(generateAdvice),
                input: "N",
                modifierFlags: .command
            ),
            UICommand(
                title: "View Favorites",
                action: #selector(viewFavorites),
                input: "F",
                modifierFlags: [.command, .shift]
            ),
            UICommand(
                title: "Statistics",
                action: #selector(viewStats),
                input: "S",
                modifierFlags: [.command, .option]
            )
        ])
        
        UIMenuSystem.main.setNeedsRebuild()
    }
    
    @objc private func generateAdvice() {
        NotificationCenter.default.post(name: .generateAdviceFromNotification, object: nil)
    }
    
    @objc private func viewFavorites() {
        NotificationCenter.default.post(name: Notification.Name("showFavorites"), object: nil)
    }
    
    @objc private func viewStats() {
        NotificationCenter.default.post(name: Notification.Name("showStats"), object: nil)
    }
}

#endif
