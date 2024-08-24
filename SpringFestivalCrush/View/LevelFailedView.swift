//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelFailedView: View {
    let level: Int
    let onTapTryAgainLevel: () -> Void
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.8, blue: 0.9), // light pink
                    Color(red: 1.0, green: 0.4, blue: 0.6), // darker pink
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    StarView(fillColor: .gray)
                    StarView(fillColor: .gray)
                    StarView(fillColor: .gray)
                }
                .padding()
                Text("Level \(level) failed")
                    .padding()
                Text("Out of moves!")
                    .padding()

                Button(action: onTapTryAgainLevel) {
                    Text("Try again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .clipShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    VStack {
        LevelFailedView(level: 2) {}
    }
}
