//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var gameModel: GameModel

    var body: some View {
        NavigationStack {
            SelectChineseZodiacView()
                .navigationTitle("Spring Festival Crush")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}
