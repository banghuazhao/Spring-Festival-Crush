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

    var body: some View {
        NavigationStack {
            SelectChineseZodiacView()
                // No title: the map is the screen, and a bar title only covers it. The bar
                // itself stays for the gear (and the DEBUG bug), with its background hidden
                // so the artwork runs behind it up to the status bar.
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
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
                    if !presenting { dailyEnvelope.refresh() }
                }
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
