//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct SelectChineseZodiacView: View {
    let chineseZodiacSigns = ["🐭 Rat", "🐮 Ox", "🐯 Tiger", "🐰 Rabbit", "🐲 Dragon", "🐍 Snake", "🐴 Horse", "🐑 Goat", "🐵 Monkey", "🐔 Rooster", "🐶 Dog", "🐷 Pig"]

    @State private var selectedZodiac: String?
    @State private var shouldPresentLevel: Bool = false

    let columnsCompact = [GridItem(.flexible()), GridItem(.flexible())]
    let columnsRegular = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.95, green: 0.9, blue: 0.85)
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 20) {
                        ForEach(chineseZodiacSigns, id: \.self) { sign in
                            ChineseZodiacButton(sign: sign) {
                                selectedZodiac = sign
                                shouldPresentLevel = true
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationDestination(isPresented: $shouldPresentLevel, destination: {
                LevelSelectionView()
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
                .font(.title)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(10)
                .padding(.all, 5)
                .foregroundStyle(.black)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SelectChineseZodiacView()
    }
}
