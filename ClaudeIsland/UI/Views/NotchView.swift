//
//  NotchView.swift
//  ClaudeIsland
//
//  The main dynamic island SwiftUI view with accurate notch shape
//

import AppKit
import CoreGraphics
import SwiftUI
import Combine

// Corner radius constants
private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()
    @StateObject private var activityCoordinator = NotchActivityCoordinator.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var previousPendingIds: Set<String> = []
    @State private var previousWaitingForInputIds: Set<String> = []
    @State private var waitingForInputTimestamps: [String: Date] = [:]  // sessionId -> when it entered waitingForInput
    @State private var isVisible: Bool = false
    @State private var isHovering: Bool = false
    @State private var isBouncing: Bool = false

    /// The primary phase for displaying cat icon animation
    private var primaryPhase: SessionPhase {
        if hasPendingPermission {
            return .waitingForApproval(PermissionContext(toolUseId: "", toolName: "pending", toolInput: nil, receivedAt: Date()))
        }
        if isProcessing {
            return .processing
        }
        if hasWaitingForInput {
            return .waitingForInput
        }
        return .idle
    }

    @Namespace private var activityNamespace

    /// Whether any Claude session is currently processing or compacting
    private var isAnyProcessing: Bool {
        sessionMonitor.instances.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    /// Whether any Claude session has a pending permission request
    private var hasPendingPermission: Bool {
        sessionMonitor.instances.contains { $0.phase.isWaitingForApproval }
    }

    /// Whether any Claude session is waiting for user input (done/ready state) within the display window
    private var hasWaitingForInput: Bool {
        let now = Date()
        let displayDuration: TimeInterval = TimeInterval(AppSettings.waitingDisplayDuration)

        return sessionMonitor.instances.contains { session in
            guard session.phase == .waitingForInput else { return false }
            // Only show if within the display window
            if let enteredAt = waitingForInputTimestamps[session.stableId] {
                return now.timeIntervalSince(enteredAt) < displayDuration
            }
            return false
        }
    }

    // MARK: - Sizing

    private var closedNotchSize: CGSize {
        CGSize(
            width: viewModel.deviceNotchRect.width,
            height: viewModel.deviceNotchRect.height
        )
    }

    /// Extra width for expanding activities (like Dynamic Island)
    private var expansionWidth: CGFloat {
        // Permission indicator adds width on left side only
        let permissionIndicatorWidth: CGFloat = hasPendingPermission ? 18 : 0

        // Expand for processing activity
        if activityCoordinator.expandingActivity.show {
            switch activityCoordinator.expandingActivity.type {
            case .claude:
                let baseWidth = 2 * max(0, closedNotchSize.height - 12) + 20
                return baseWidth + permissionIndicatorWidth
            case .none:
                break
            }
        }

        // Expand for pending permissions (left indicator) or waiting for input (checkmark on right)
        if hasPendingPermission {
            return 2 * max(0, closedNotchSize.height - 12) + 20 + permissionIndicatorWidth
        }

        // Waiting for input just shows checkmark on right, no extra left indicator
        if hasWaitingForInput {
            return 2 * max(0, closedNotchSize.height - 12) + 20
        }

        return 0
    }

    private var notchSize: CGSize {
        switch viewModel.status {
        case .closed, .popping:
            return closedNotchSize
        case .opened:
            return viewModel.openedSize
        }
    }

    /// Width of the closed content (notch + any expansion)
    private var closedContentWidth: CGFloat {
        closedNotchSize.width + expansionWidth
    }

    // MARK: - Corner Radii

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    // Animation springs
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Outer container does NOT receive hits - only the notch content does
            VStack(spacing: 0) {
                notchLayout
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        alignment: .top
                    )
                    .padding(
                        .horizontal,
                        viewModel.status == .opened
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], viewModel.status == .opened ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: (viewModel.status == .opened || isHovering) ? .black.opacity(0.7) : .clear,
                        radius: 6
                    )
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        maxHeight: viewModel.status == .opened ? notchSize.height : nil,
                        alignment: .top
                    )
                    .animation(viewModel.status == .opened ? openAnimation : closeAnimation, value: viewModel.status)
                    .animation(openAnimation, value: notchSize) // Animate container size changes between content types
                    .animation(.smooth, value: activityCoordinator.expandingActivity)
                    .animation(.smooth, value: hasPendingPermission)
                    .animation(.smooth, value: hasWaitingForInput)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                            isHovering = hovering
                        }
                    }
                    .onTapGesture {
                        if viewModel.status != .opened {
                            viewModel.notchOpen(reason: .click)
                        }
                    }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
            // On non-notched devices, keep visible so users have a target to interact with
            if !viewModel.hasPhysicalNotch {
                isVisible = true
            }
        }
        .onChange(of: viewModel.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: sessionMonitor.pendingInstances) { _, sessions in
            handlePendingSessionsChange(sessions)
        }
        .onChange(of: sessionMonitor.instances) { _, instances in
            handleProcessingChange()
            handleWaitingForInputChange(instances)
        }
    }

    // MARK: - Notch Layout

    private var isProcessing: Bool {
        activityCoordinator.expandingActivity.show && activityCoordinator.expandingActivity.type == .claude
    }

    /// Whether to show the expanded closed state (processing, pending permission, or waiting for input)
    private var showClosedActivity: Bool {
        isProcessing || hasPendingPermission || hasWaitingForInput
    }

    @ViewBuilder
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always present, contains crab and spinner that persist across states
            headerRow
                .frame(height: max(24, closedNotchSize.height))

            // Main content only when opened
            if viewModel.status == .opened {
                contentView
                    .frame(width: notchSize.width - 24) // Fixed width to prevent reflow
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.smooth(duration: 0.35)),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        )
                    )
            }
        }
    }

    // MARK: - Header Row (persists across states)

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Left side - show all session cats + optional permission indicator (visible when processing, pending, or waiting for input)
            if showClosedActivity {
                HStack(spacing: 2) {
                    // Arrange cats based on count: 1=1row, 2=horizontal, 3=triangle, 4=square
                    MultiCatLayout(sessions: Array(sessionMonitor.instances), maxSize: 42)

                    // Permission indicator only (amber) - waiting for input shows checkmark on right
                    if hasPendingPermission {
                        PermissionIndicatorIcon(size: 14, color: Color(red: 0.85, green: 0.47, blue: 0.34))
                            .matchedGeometryEffect(id: "status-indicator", in: activityNamespace, isSource: showClosedActivity)
                    }
                }
                .frame(width: viewModel.status == .opened ? nil : sideWidth + (hasPendingPermission ? 18 : 0))
                .padding(.leading, viewModel.status == .opened ? 8 : 0)
            }

            // Center content
            if viewModel.status == .opened {
                // Opened: show header content
                openedHeaderContent
            } else if !showClosedActivity {
                // Closed without activity: empty space
                Rectangle()
                    .fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            } else {
                // Closed with activity: black spacer (with optional bounce)
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))
            }

            // Right side - spinner when processing/pending, checkmark when waiting for input
            if showClosedActivity {
                if isProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                } else if hasWaitingForInput {
                    // Checkmark for waiting-for-input on the right side
                    ReadyForInputIndicatorIcon(size: 14, color: TerminalColors.green)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                }
            }
        }
        .frame(height: closedNotchSize.height)
    }

    private var sideWidth: CGFloat {
        max(0, closedNotchSize.height - 12) + 10
    }

    // MARK: - Opened Header Content

    @ViewBuilder
    private var openedHeaderContent: some View {
        HStack(spacing: 0.12) {
            // Show all session cats (even when not showing activity in headerRow)
            // In opened state, use larger icons with MultiCatLayout
            if !showClosedActivity {
                OpenedMultiCatLayout(sessions: Array(sessionMonitor.instances), baseSize: 28)
                    .padding(.leading, 8)
            }

            Spacer()

            // Menu toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleMenu()
                    if viewModel.contentType == .menu {
                        updateManager.markUpdateSeen()
                    }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.contentType == .menu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())

                    // Green dot for unseen update
                    if updateManager.hasUnseenUpdate && viewModel.contentType != .menu {
                        Circle()
                            .fill(TerminalColors.green)
                            .frame(width: 6, height: 6)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content View (Opened State)

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch viewModel.contentType {
            case .instances:
                ClaudeInstancesView(
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
            case .menu:
                NotchMenuView(viewModel: viewModel)
            case .chat(let session):
                ChatView(
                    sessionId: session.sessionId,
                    initialSession: session,
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
            }
        }
        .frame(width: notchSize.width - 24) // Fixed width to prevent text reflow
        // Removed .id() - was causing view recreation and performance issues
    }

    // MARK: - Event Handlers

    private func handleProcessingChange() {
        if isAnyProcessing || hasPendingPermission {
            // Show claude activity when processing or waiting for permission
            activityCoordinator.showActivity(type: .claude)
            isVisible = true
        } else if hasWaitingForInput {
            // Keep visible for waiting-for-input but hide the processing spinner
            activityCoordinator.hideActivity()
            isVisible = true
        } else {
            // Hide activity when done
            activityCoordinator.hideActivity()

            // Delay hiding the notch until animation completes
            // Don't hide on non-notched devices - users need a visible target
            if viewModel.status == .closed && viewModel.hasPhysicalNotch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isAnyProcessing && !hasPendingPermission && !hasWaitingForInput && viewModel.status == .closed {
                        // Keep visible if setting enabled and sessions exist
                        if AppSettings.keepNotchVisible && !self.sessionMonitor.instances.isEmpty {
                            return
                        }
                        isVisible = false
                    }
                }
            }
        }
    }

    private func handleStatusChange(from oldStatus: NotchStatus, to newStatus: NotchStatus) {
        switch newStatus {
        case .opened, .popping:
            isVisible = true
            // Clear waiting-for-input timestamps only when manually opened (user acknowledged)
            if viewModel.openReason == .click || viewModel.openReason == .hover {
                waitingForInputTimestamps.removeAll()
            }
        case .closed:
            // Don't hide on non-notched devices - users need a visible target
            guard viewModel.hasPhysicalNotch else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if viewModel.status == .closed && !self.isAnyProcessing && !self.hasPendingPermission && !self.hasWaitingForInput && !self.activityCoordinator.expandingActivity.show {
                    // Keep visible if setting enabled and sessions exist
                    if AppSettings.keepNotchVisible && !self.sessionMonitor.instances.isEmpty {
                        return
                    }
                    self.isVisible = false
                }
            }
        }
    }

    private func handlePendingSessionsChange(_ sessions: [SessionState]) {
        let currentIds = Set(sessions.map { $0.stableId })
        let newPendingIds = currentIds.subtracting(previousPendingIds)

        if !newPendingIds.isEmpty &&
           viewModel.status == .closed &&
           !TerminalVisibilityDetector.isTerminalVisibleOnCurrentSpace() {
            viewModel.notchOpen(reason: .notification)
        }

        previousPendingIds = currentIds
    }

    private func handleWaitingForInputChange(_ instances: [SessionState]) {
        // Get sessions that are now waiting for input
        let waitingForInputSessions = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingForInputSessions.map { $0.stableId })
        let newWaitingIds = currentIds.subtracting(previousWaitingForInputIds)

        // Track timestamps for newly waiting sessions
        let now = Date()
        for session in waitingForInputSessions where newWaitingIds.contains(session.stableId) {
            waitingForInputTimestamps[session.stableId] = now
        }

        // Clean up timestamps for sessions no longer waiting
        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        // Bounce the notch when a session newly enters waitingForInput state
        if !newWaitingIds.isEmpty {
            // Get the sessions that just entered waitingForInput
            let newlyWaitingSessions = waitingForInputSessions.filter { newWaitingIds.contains($0.stableId) }

            // Play notification sound if the session is not actively focused
            if let soundName = AppSettings.notificationSound.soundName {
                // Check if we should play sound (async check for tmux pane focus)
                Task {
                    let shouldPlaySound = await shouldPlayNotificationSound(for: newlyWaitingSessions)
                    if shouldPlaySound {
                        await MainActor.run {
                            NSSound(named: soundName)?.play()
                        }
                    }
                }
            }

            // Trigger bounce animation to get user's attention
            DispatchQueue.main.async {
                isBouncing = true
                // Bounce back after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isBouncing = false
                }
            }

            // Schedule hiding the checkmark after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [self] in
                // Trigger a UI update to re-evaluate hasWaitingForInput
                handleProcessingChange()
            }
        }

        previousWaitingForInputIds = currentIds
    }

    /// Determine if notification sound should play for the given sessions
    /// Returns true if ANY session is not actively focused
    private func shouldPlayNotificationSound(for sessions: [SessionState]) async -> Bool {
        for session in sessions {
            guard let pid = session.pid else {
                // No PID means we can't check focus, assume not focused
                return true
            }

            let isFocused = await TerminalVisibilityDetector.isSessionFocused(sessionPid: pid)
            if !isFocused {
                return true
            }
        }

        return false
    }
}

// MARK: - Multi Cat Layout
struct MultiCatLayout: View {
    let sessions: [SessionState]
    let maxSize: CGFloat

    /// Show first 4 sessions, then +N indicator
    private let maxVisible = 4

    init(sessions: [SessionState], maxSize: CGFloat = 24) {
        self.sessions = sessions
        self.maxSize = maxSize
    }

    /// Calculate icon size based on session count to fit within maxSize
    private var iconSize: CGFloat {
        let spacing: CGFloat = 1
        let visibleCount = min(sessions.count, maxVisible)
        switch visibleCount {
        case 0:
            return 0
        case 1:
            return maxSize
        default:
            // Multiple cats scale down: 2 * size + spacing <= maxSize
            return (maxSize - spacing) / 2
        }
    }

    /// Number of sessions beyond the visible ones
    private var overflowCount: Int {
        max(0, sessions.count - maxVisible)
    }

    var body: some View {
        let visibleSessions = Array(sessions.prefix(maxVisible))

        ZStack(alignment: .bottomTrailing) {
            // Main cat layout
            mainLayout(sessions: visibleSessions)

            // Overflow indicator
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(3)
                    .offset(x: 2, y: 2)
            }
        }
    }

    @ViewBuilder
    private func mainLayout(sessions: [SessionState]) -> some View {
        switch sessions.count {
        case 0:
            EmptyView()
        case 1:
            StatusIcon(phase: sessions[0].phase, size: maxSize)
        case 2:
            HStack(alignment: .top, spacing: 0.1) {
                StatusIcon(phase: sessions[0].phase, size: iconSize)
                StatusIcon(phase: sessions[1].phase, size: iconSize)
            }
        case 3:
            VStack(spacing: 0) {
                StatusIcon(phase: sessions[0].phase, size: iconSize)
                    .offset(y: iconSize * 0.3)
                HStack(spacing: 0.1) {
                    StatusIcon(phase: sessions[1].phase, size: iconSize)
                    StatusIcon(phase: sessions[2].phase, size: iconSize)
                }
            }
        default:
            VStack(spacing: 0) {
                HStack(spacing: 0.1) {
                    StatusIcon(phase: sessions[0].phase, size: iconSize)
                        .offset(y: iconSize * 0.3)
                    StatusIcon(phase: sessions[1].phase, size: iconSize)
                        .offset(y: iconSize * 0.3)
                }
                HStack(spacing: 0.1) {
                    StatusIcon(phase: sessions[2].phase, size: iconSize)
                    StatusIcon(phase: sessions[3].phase, size: iconSize)
                }
            }
        }
    }
}

// MARK: - Opened Multi Cat Layout (for expanded notch view with larger icons)
struct OpenedMultiCatLayout: View {
    let sessions: [SessionState]
    let baseSize: CGFloat

    /// Show first 4 sessions, then +N indicator
    private let maxVisible = 4

    init(sessions: [SessionState], baseSize: CGFloat = 28) {
        self.sessions = sessions
        self.baseSize = baseSize
    }

    /// Calculate icon size based on session count to fit within baseSize
    private var iconSize: CGFloat {
        let spacing: CGFloat = 1
        let visibleCount = min(sessions.count, maxVisible)
        switch visibleCount {
        case 0:
            return 0
        case 1:
            return baseSize
        default:
            // Multiple cats scale down to fit
            return (baseSize - spacing) / 2
        }
    }

    /// Number of sessions beyond the visible ones
    private var overflowCount: Int {
        max(0, sessions.count - maxVisible)
    }

    var body: some View {
        let visibleSessions = Array(sessions.prefix(maxVisible))

        ZStack(alignment: .bottomTrailing) {
            // Main cat layout
            mainLayout(sessions: visibleSessions)

            // Overflow indicator
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(x: 4, y: 4)
            }
        }
    }

    @ViewBuilder
    private func mainLayout(sessions: [SessionState]) -> some View {
        switch sessions.count {
        case 0:
            EmptyView()
        case 1:
            MenuBarCatIcon(phase: sessions[0].phase, size: baseSize)
        case 2:
            HStack(alignment: .top, spacing: 0.1) {
                MenuBarCatIcon(phase: sessions[0].phase, size: iconSizeForPhase(sessions[0].phase))
                MenuBarCatIcon(phase: sessions[1].phase, size: iconSizeForPhase(sessions[1].phase))
            }
        case 3:
            VStack(spacing: 0) {
                MenuBarCatIcon(phase: sessions[0].phase, size: iconSizeForPhase(sessions[0].phase))
                    .offset(y: iconSize * 0.3)
                HStack(spacing: 0.1) {
                    MenuBarCatIcon(phase: sessions[1].phase, size: iconSizeForPhase(sessions[1].phase))
                    MenuBarCatIcon(phase: sessions[2].phase, size: iconSizeForPhase(sessions[2].phase))
                }
            }
        default:
            VStack(spacing: 0) {
                HStack(spacing: 0.1) {
                    MenuBarCatIcon(phase: sessions[0].phase, size: iconSizeForPhase(sessions[0].phase))
                        .offset(y: iconSize * 0.3)
                    MenuBarCatIcon(phase: sessions[1].phase, size: iconSizeForPhase(sessions[1].phase))
                        .offset(y: iconSize * 0.3)
                }
                HStack(spacing: 0.1) {
                    MenuBarCatIcon(phase: sessions[2].phase, size: iconSizeForPhase(sessions[2].phase))
                    MenuBarCatIcon(phase: sessions[3].phase, size: iconSizeForPhase(sessions[3].phase))
                }
            }
        }
    }

    /// Returns icon size, with running phases getting a larger size
    private func iconSizeForPhase(_ phase: SessionPhase) -> CGFloat {
        switch phase {
        case .processing, .compacting:
            return iconSize * 1.3  // Running icons are bigger
        default:
            return iconSize
        }
    }
}
