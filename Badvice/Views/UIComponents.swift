import SwiftUI

// MARK: - Skeleton Loader

struct SkeletonLoader: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var isAnimating = false
    
    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct AdviceCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLoader(height: 24)
            SkeletonLoader(width: 200, height: 16)
            HStack {
                SkeletonLoader(width: 80, height: 12)
                Spacer()
                SkeletonLoader(width: 60, height: 12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }
}

struct ListSkeletonLoader: View {
    let count: Int
    
    init(count: Int = 5) {
        self.count = count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                AdviceCardSkeleton()
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isActive = false
    let onComplete: () -> Void
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    var context = context
                    context.opacity = isActive ? 1 : 0
                    
                    let rect = CGRect(
                        x: particle.x - 6 * particle.scale,
                        y: particle.y - 6 * particle.scale,
                        width: 12 * particle.scale,
                        height: 12 * particle.scale
                    )
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                updateParticles()
            }
        }
        .allowsHitTesting(false)
    }
    
    mutating func start(from point: CGPoint, particleCount: Int = 50) {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle.random(at: point)
        }
        isActive = true
    }
    
    private mutating func updateParticles() {
        guard isActive else { return }
        
        for i in particles.indices {
            particles[i].x += particles[i].velocity.dx
            particles[i].y += particles[i].velocity.dy
            particles[i].velocity.dy += 0.3 // gravity
            particles[i].rotation += particles[i].rotationVelocity
        }
        
        // Remove particles that are off screen
        particles.removeAll { $0.y > UIScreen.main.bounds.height + 50 }
        
        if particles.isEmpty {
            isActive = false
            onComplete()
        }
    }
}

// MARK: - Pull to Refresh Indicator

struct RefreshIndicator: View {
    let isRefreshing: Bool
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                .frame(width: 36, height: 36)
            
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(rotation))
        }
        .onChange(of: isRefreshing) { _, newValue in
            if newValue {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    let hapticEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && hapticEnabled {
                    HapticsManager.playSelection()
                }
            }
    }
}

// MARK: - Pulse View Modifier

struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        scale = 1.1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                    }
                }
            }
    }
}

extension View {
    func pulse(when isActive: Bool) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Card Flip Animation

struct FlippableCard<Front, Back>: View where Front: View, Back: View {
    let front: () -> Front
    let back: () -> Back
    @Binding var isFlipped: Bool
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            front()
                .opacity(rotation < 90 ? 1 : 0)
            
            back()
                .rotation3DEffect(.radians(.pi + rotation * .pi / 180), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation >= 90 ? 1 : 0)
        }
        .onChange(of: isFlipped) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                rotation = newValue ? 180 : 0
            }
        }
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    @State private var isVisible = false
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.white)
                Text("You're offline")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .clipShape(Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text(title)
                .font(.title3.weight(.semibold))
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(_ state: EmptyState) {
        self.icon = state.icon
        self.title = state.title
        self.message = state.message
        self.actionTitle = state.actionTitle
        self.action = state.action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3.weight(.semibold))
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Level Progress Badge

struct LevelBadge: View {
    let level: Int
    let xpProgress: XPProgress?
    let size: CGFloat
    
    init(level: Int, size: CGFloat = 50) {
        self.level = level
        self.xpProgress = nil
        self.size = size
    }
    
    init(progress: XPProgress, size: CGFloat = 50) {
        self.level = progress.level
        self.xpProgress = progress
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(levelColor.opacity(0.2))
                .frame(width: size, height: size)
            
            Circle()
                .strokeBorder(levelColor, lineWidth: 3)
                .frame(width: size, height: size)
            
            if let progress = xpProgress {
                Circle()
                    .trim(from: 0, to: progress.xpProgress)
                    .stroke(levelColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(spacing: 0) {
                Text("\(level)")
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(levelColor)
            }
        }
    }
    
    private var levelColor: Color {
        switch level {
        case 1..<5: return .green
        case 5..<10: return .blue
        case 10..<25: return .purple
        case 25..<50: return .orange
        case 50..<100: return .pink
        default: return .red
        }
    }
}

// MARK: - Achievement Badge View

struct AchievementBadgeView: View {
    let badge: AchievementBadge
    let isUnlocked: Bool
    let size: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                
                Image(systemName: badge.icon)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(isUnlocked ? .accentColor : .gray)
            }
            
            Text(badge.title)
                .font(.caption2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .lineLimit(1)
        }
        .opacity(isUnlocked ? 1 : 0.5)
    }
}

// MARK: - Swipeable Card Actions

struct SwipeableCardActions: ViewModifier {
    let onSave: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -100)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -50 {
                                showingActions = true
                                offset = -80
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
            .overlay(alignment: .trailing) {
                if showingActions {
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation { offset = 0; showingActions = false }
                            onSave()
                        }) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Button(action: {
                            withAnimation { offset = 0; showingActions = false }
                            onShare()
                        }) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundStyle(.green)
                        }
                        
                        Button(action: {
                            withAnimation { offset = 0; showingActions = false }
                            onCopy()
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.title2)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing))
                }
            }
    }
}

extension View {
    func swipeableCardActions(
        onSave: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) -> some View {
        modifier(SwipeableCardActions(onSave: onSave, onShare: onShare, onCopy: onCopy))
    }
}

// MARK: - Tutorial Overlay

struct TutorialOverlay: View {
    let tips: [TutorialTip]
    @Binding var currentTipIndex: Int
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if currentTipIndex < tips.count - 1 {
                        currentTipIndex += 1
                    } else {
                        onComplete()
                    }
                }
            
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: tips[currentTipIndex].icon)
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                
                Text(tips[currentTipIndex].title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                Text(tips[currentTipIndex].description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 8) {
                    ForEach(0..<tips.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentTipIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 10)
                
                Spacer()
                
                Button(action: {
                    if currentTipIndex < tips.count - 1 {
                        currentTipIndex += 1
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentTipIndex < tips.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}
