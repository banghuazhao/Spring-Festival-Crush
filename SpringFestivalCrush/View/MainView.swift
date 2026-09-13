//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var settingModel: SettingModel
    @Environment(\.modelContext) private var modelContext

    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    var body: some View {
        NavigationStack {
            SelectChineseZodiacView()
                // No title: the map is the screen, and a bar title only covers it. The bar
                // itself stays for the gear (and the DEBUG bug), with its background hidden
                // so the artwork runs behind it up to the status bar.
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
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
