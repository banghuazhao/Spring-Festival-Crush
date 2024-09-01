//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct SelectChineseZodiacView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var themeModel: ThemeModel
    @EnvironmentObject var settingModel: SettingModel

    var unlockAll: Bool {
        settingModel.unlockAllLevels
    }

    @State private var selectedZodiac: ChineseZodiac?
    @State private var shouldPresentLevel: Bool = false

    let columnsCompact = [GridItem(.flexible()), GridItem(.flexible())]
    let columnsRegular = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    @State private var presentZodiacUnavailable: Bool = false
    @State private var presentZodiacIsLocked = false


    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeModel.pageBackgroundColor
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 20) {
                        ForEach(gameModel.zodiacRecords) { zodiacRecord in
                            ZodiacButton(
                                title: zodiacRecord.zodiacType.title,
                                isUnlocked: zodiacRecord.isUnlocked || unlockAll,
                                presentZodiacIsLocked: $presentZodiacIsLocked
                            ) {
                                let zodiac = Zodiac.all.first { $0.zodiacType == zodiacRecord.zodiacType }
                                if zodiac?.isAvailable ?? false {
                                    gameModel.selectZodiac(zodiacRecord)
                                    shouldPresentLevel = true
                                } else {
                                    presentZodiacUnavailable = true
                                }
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
        .easyToast(isPresented: $presentZodiacUnavailable, message: "Feature in Development. Coming Soon!")
        .easyToast(
            isPresented: $presentZodiacIsLocked,
            message: "Complete previous levels to unlock"
        )
    }
}

struct ZodiacButton: View {
    let title: String
    let isUnlocked: Bool
    @Binding var presentZodiacIsLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
                                    Color(red: 1.0, green: 0.4, blue: 0.0), // Deep orange
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
                                    Color.clear,
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
        .disabled(!isUnlocked)
        .overlay {
            if !isUnlocked {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .onTapGesture {
            if !isUnlocked {
                presentZodiacIsLocked = true
            }
        }
    }
}
