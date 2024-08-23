//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct SelectChineseZodiacView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var themeModel: ThemeModel

    let chineseZodiacs: [ChineseZodiac] = ChineseZodiac.allCases

    @State private var selectedZodiac: ChineseZodiac?
    @State private var shouldPresentLevel: Bool = false

    let columnsCompact = [GridItem(.flexible()), GridItem(.flexible())]
    let columnsRegular = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeModel.pageBackgroundColor
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 20) {
                        ForEach(chineseZodiacs, id: \.self) { chineseZodiac in
                            ChineseZodiacButton(sign: chineseZodiac.rawValue) {
                                gameModel.selectZodiac(chineseZodiac)
                                shouldPresentLevel = true
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationDestination(isPresented: $shouldPresentLevel, destination: {
                SelectLevelView()
            })
        }
    }
}

struct ChineseZodiacButton: View {
    let sign: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(sign)
                .font(.system(size: 20, weight: .semibold, design: .rounded)) // Rounded font for a playful look
                .foregroundColor(Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 2, y: 2) // Subtle shadow for text
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.0), // Bright orange
                                    Color(red: 1.0, green: 0.4, blue: 0.0),  // Deep orange
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(Capsule())

                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    Color.white.opacity(0.5), // Softer highlight
                                    Color.clear
                                ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(Capsule())
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                )
                .clipShape(Capsule())
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 5, y: 5) // Outer shadow for 3D lift
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.all, 5)
        }
        .buttonStyle(PlainButtonStyle()) // Minimal button styling
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SelectChineseZodiacView()
    }
}
