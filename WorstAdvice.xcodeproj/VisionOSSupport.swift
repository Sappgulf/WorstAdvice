import SwiftUI

#if os(visionOS)
import RealityKit

// MARK: - visionOS Spatial App

@available(visionOS 1.0, *)
struct BadviceSpatialApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            SpatialContentView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 800, height: 600, depth: 400)
        
        ImmersiveSpace(id: "immersive") {
            ImmersiveAdviceSpace()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .full)
    }
}

// MARK: - Spatial Content View

@available(visionOS 1.0, *)
struct SpatialContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var currentAdvice = "Tap to generate spatial bad advice"
    @State private var category: AdviceCategory = .tech
    @State private var isGenerating = false
    @State private var showImmersive = false
    @State private var rotation: Angle = .zero
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(AdviceCategory.allCases) { cat in
                Button {
                    category = cat
                } label: {
                    Label(cat.title, systemImage: cat.icon)
                }
            }
            .navigationTitle("Categories")
        } detail: {
            // Main content
            ZStack {
                // 3D advice card floating in space
                adviceCard
                    .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: rotation)
                    .onAppear {
                        rotation = .degrees(360)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                controlPanel
            }
        }
    }
    
    private var adviceCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: 600, height: 400)
            .overlay {
                VStack(spacing: 20) {
                    Label(category.title, systemImage: category.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                    
                    Text(currentAdvice)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    if isGenerating {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
                .padding()
            }
            .shadow(radius: 20)
            .hoverEffect()
    }
    
    private var controlPanel: some View {
        HStack(spacing: 20) {
            Button {
                generateAdvice()
            } label: {
                Label("Generate", systemImage: "sparkles")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isGenerating)
            
            Button {
                Task {
                    if showImmersive {
                        await dismissImmersiveSpace()
                    } else {
                        await openImmersiveSpace(id: "immersive")
                    }
                    showImmersive.toggle()
                }
            } label: {
                Label(
                    showImmersive ? "Exit Immersive" : "Enter Immersive",
                    systemImage: showImmersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .buttonStyle(.bordered)
        }
        .glassBackgroundEffect()
    }
    
    private func generateAdvice() {
        isGenerating = true
        
        let advice = [
            "If the meeting is unclear, add more stakeholders.",
            "Documentation is what you write after the app ships.",
            "User feedback is just pre-release anxiety.",
            "If it works in VR, production is ready.",
            "Spatial computing means meetings in your living room."
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            currentAdvice = advice.randomElement() ?? advice[0]
            isGenerating = false
        }
    }
}

// MARK: - Immersive Space

@available(visionOS 1.0, *)
struct ImmersiveAdviceSpace: View {
    @State private var adviceParticles: [AdviceParticle] = []
    
    struct AdviceParticle: Identifiable {
        let id = UUID()
        let position: SIMD3<Float>
        let text: String
        let color: Color
    }
    
    var body: some View {
        RealityView { content in
            // Create 3D text entities floating in space
            let adviceTexts = [
                "Confidence",
                "Chaos",
                "Leadership",
                "Strategy",
                "Innovation"
            ]
            
            for (index, text) in adviceTexts.enumerated() {
                let angle = Float(index) * (2 * .pi / Float(adviceTexts.count))
                let radius: Float = 1.5
                let x = cos(angle) * radius
                let z = sin(angle) * radius
                let y = Float.random(in: -0.5...0.5)
                
                // Create text entity
                let textEntity = ModelEntity()
                textEntity.position = SIMD3(x, y, z)
                
                content.add(textEntity)
            }
            
            // Add ambient particles
            for _ in 0..<50 {
                let particle = ModelEntity(
                    mesh: .generateSphere(radius: 0.02),
                    materials: [SimpleMaterial(color: .orange, isMetallic: true)]
                )
                
                particle.position = SIMD3(
                    Float.random(in: -2...2),
                    Float.random(in: -2...2),
                    Float.random(in: -2...2)
                )
                
                content.add(particle)
            }
        }
    }
}

// MARK: - visionOS Widget

@available(visionOS 1.0, *)
struct VisionAdviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VisionAdviceWidget", provider: VisionAdviceProvider()) { entry in
            VisionAdviceWidgetView(entry: entry)
        }
        .configurationDisplayName("Spatial Advice")
        .description("Bad advice in your space")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(visionOS 1.0, *)
struct VisionAdviceProvider: TimelineProvider {
    func placeholder(in context: Context) -> VisionAdviceEntry {
        VisionAdviceEntry(date: Date(), advice: "Spatial advice awaits")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (VisionAdviceEntry) -> Void) {
        completion(VisionAdviceEntry(date: Date(), advice: "If it works in VR, ship it"))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<VisionAdviceEntry>) -> Void) {
        let entry = VisionAdviceEntry(date: Date(), advice: "Spatial meetings are just zoom with depth")
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct VisionAdviceEntry: TimelineEntry {
    let date: Date
    let advice: String
}

@available(visionOS 1.0, *)
struct VisionAdviceWidgetView: View {
    let entry: VisionAdviceEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                
                Text(entry.advice)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

#endif
