//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelSelectionView: View {
    @EnvironmentObject var gameModel: GameModel

    let levels = Array(1 ... 10) // Example: 10 levels available

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.9, blue: 0.85)
                .edgesIgnoringSafeArea(.all)
            ScrollView {
                ForEach(levels, id: \.self) { level in
                    Button(action: {
                        gameModel.selectLevel(level)
                        gameModel.shouldPresentGame = true
                    }) {
                        Text("Level \(level)")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .fullScreenCover(isPresented: $gameModel.shouldPresentGame) {
            GeometryReader { geo in
                GameView(screenSize: geo.size)
            }
            
        }

        .navigationTitle("Select Level")
    }
}
