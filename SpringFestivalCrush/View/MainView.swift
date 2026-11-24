//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// The red envelope in the map toolbar, with a dot while today's gift is unopened.
private struct DailyEnvelopeToolbarIcon: View {
    let isReady: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @State private var bounce = false

    var body: some View {
        RedEnvelopeArt(width: 22)
            .rotationEffect(.degrees(bounce ? -8 : 0))
            .overlay(alignment: .topTrailing) {
                if isReady {
                    Circle()
                        .fill(AppTheme.festivalGold)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                        .offset(x: 4, y: -3)
                }
            }
            .frame(width: 44, height: 44)
            .onAppear { updateBounce() }
            .onChange(of: isReady) { _, _ in updateBounce() }
    }

    private func updateBounce() {
        guard isReady, !systemReduceMotion, !reducedEffects else {
            bounce = false
            return
        }
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
    }
}

struct MainView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var settingModel: SettingModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dailyEnvelope = DailyEnvelopeModel()
    @State private var showDailyEnvelope = false
    /// The envelope pops up by itself at most once per launch; the toolbar button stays.
    @State private var didAutoPresentEnvelope = false
    @State private var showRuleHandbook = false
    /// A rule has unlocked that the player hasn't opened in the handbook yet.
    @State private var hasNewRules = false
    @ObservedObject private var premium = PremiumStore.shared
    @State private var showPremium = false
    @State private var showCollection = false
    @State private var hasNewCards = false
    @State private var revealedCard: ZodiacCard?

    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    private func presentEnvelopeIfReady() {
        dailyEnvelope.refresh()
        guard !didAutoPresentEnvelope, dailyEnvelope.isReady,
              !gameModel.shouldPresentGame, gameModel.gameState == .notStart,
              !ReviewPromptStore.isRunningTests else { return }
        #if DEBUG
        guard !gameModel.shouldPresentDebugDemo else { return }
        #endif
        #if !targetEnvironment(macCatalyst)
        guard !ToolRewardAdManager.shared.isPresenting else { return }
        #endif
        didAutoPresentEnvelope = true
        showDailyEnvelope = true
    }

    private func refreshRuleHandbookDot() {
        let curriculum = RuleCurriculum.shared
        let seen = RuleHandbookStore.seen()
        hasNewRules = curriculum.rules.contains { rule in
            !seen.contains(rule)
                && curriculum.isUnlocked(rule) { settingModel.unlockAllLevels || gameModel.hasReached($0) }
        }
    }

    private func refreshCollectionDot() {
        hasNewCards = ZodiacCardStore.hasUnseen(ZodiacCollection.cards(from: gameModel.zodiacRecords))
    }

    /// Waits for the game cover to finish closing, so the card has the screen to itself.
    private func presentEarnedCard() {
        guard let zodiac = gameModel.takeCardReveal(),
              let card = ZodiacCollection.cards(from: gameModel.zodiacRecords).first(where: { $0.zodiac == zodiac })
        else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            revealedCard = card
        }
    }

    var body: some View {
        NavigationStack {
            SelectChineseZodiacView()
                // No title: the map is the screen, and a bar title only covers it. The bar
                // itself stays for the gear (and the DEBUG bug), with its background hidden
                // so the artwork runs behind it up to the status bar.
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            HapticManager.buttonTap()
                            showDailyEnvelope = true
                        } label: {
                            DailyEnvelopeToolbarIcon(isReady: dailyEnvelope.isReady)
                        }
                        .accessibilityLabel(Text("Daily red envelope"))
                        .accessibilityValue(dailyEnvelope.isReady ? Text("Ready to open") : Text("Opened today"))
                        .accessibilityIdentifier("daily-envelope-toolbar")
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !premium.isPremium {
                            Button {
                                HapticManager.buttonTap()
                                showPremium = true
                            } label: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(AppTheme.festivalGold)
                            }
                            .accessibilityLabel(Text("Premium"))
                            .accessibilityIdentifier("premium-toolbar")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            HapticManager.buttonTap()
                            showCollection = true
                        } label: {
                            Image(systemName: "rectangle.stack.fill")
                                .foregroundStyle(AppTheme.festivalGold)
                                .overlay(alignment: .topTrailing) {
                                    if hasNewCards {
                                        Circle()
                                            .fill(AppTheme.festivalRed)
                                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                            .frame(width: 10, height: 10)
                                            .offset(x: 6, y: -5)
                                    }
                                }
                        }
                        .accessibilityLabel(Text("Zodiac collection"))
                        .accessibilityValue(hasNewCards ? Text("New card") : Text(verbatim: ""))
                        .accessibilityIdentifier("collection-toolbar")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            HapticManager.buttonTap()
                            showRuleHandbook = true
                        } label: {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(AppTheme.festivalGold)
                                .overlay(alignment: .topTrailing) {
                                    if hasNewRules {
                                        Circle()
                                            .fill(AppTheme.festivalGold)
                                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                            .frame(width: 10, height: 10)
                                            .offset(x: 6, y: -5)
                                    }
                                }
                        }
                        .accessibilityLabel(Text("Rule handbook"))
                        .accessibilityValue(hasNewRules ? Text("New rule") : Text(verbatim: ""))
                        .accessibilityIdentifier("rule-handbook-toolbar")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(AppTheme.creamHighlight)
                        }
                        .accessibilityLabel(Text("Settings"))
                    }
                    #if DEBUG
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showDebugMenu = true
                        } label: {
                            Image(systemName: "ladybug.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    #endif
                }
                #if DEBUG
                .sheet(isPresented: $showDebugMenu) {
                    DebugMenuView()
                }
                .fullScreenCover(isPresented: $gameModel.shouldPresentDebugDemo) {
                    GeometryReader { geo in
                        GameView(screenSize: geo.size)
                    }
                }
                #endif
                .onAppear {
                    gameModel.initializeRecords(modelContext: modelContext)
                    refreshRuleHandbookDot()
                    refreshCollectionDot()
                }
                .sheet(isPresented: $showPremium) { PremiumView() }
                .sheet(isPresented: $showCollection, onDismiss: refreshCollectionDot) {
                    ZodiacCollectionView()
                        .environmentObject(gameModel)
                }
                .sheet(item: $revealedCard, onDismiss: refreshCollectionDot) { card in
                    ZodiacCardRevealView(card: card)
                }
                .sheet(isPresented: $showRuleHandbook, onDismiss: refreshRuleHandbookDot) {
                    RuleHandbookView()
                        .environmentObject(gameModel)
                        .environmentObject(settingModel)
                }
                .sheet(isPresented: $showDailyEnvelope) {
                    DailyEnvelopeView(envelope: dailyEnvelope)
                        .environmentObject(gameModel)
                }
                .task {
                    // Never stack the envelope on the privacy form: wait for consent first,
                    // then give the map a moment to settle.
                    #if !targetEnvironment(macCatalyst)
                    _ = await ConsentManager.shared.gatherConsent()
                    #endif
                    try? await Task.sleep(for: .seconds(0.8))
                    presentEnvelopeIfReady()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    dailyEnvelope.refresh()
                }
                .onChange(of: gameModel.shouldPresentGame) { _, presenting in
                    if !presenting {
                        dailyEnvelope.refresh()
                        refreshRuleHandbookDot()
                        refreshCollectionDot()
                        presentEarnedCard()
                    }
                }
                .onChange(of: settingModel.unlockAllLevels) { _, _ in refreshRuleHandbookDot() }
            #if !targetEnvironment(macCatalyst)
                .task {
                    await ConsentManager.shared.gatherConsent()
                }
            #endif
                .task {
                    await BackgroundMusicManager.shared.playDefaultBackgroundMusic()
                }
        }
    }
}
