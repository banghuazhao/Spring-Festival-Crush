//
// Created by Banghua Zhao on 30/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let duration: Double

    enum Position {
        case top
        case center
        case bottom
    }

    let position: Position

    @State private var showToast: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if showToast {
                    toastView
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue == true {
                    withAnimation {
                        showToast = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(duration) * 1000000000)
                        withAnimation {
                            isPresented = false
                            showToast = false
                        }
                    }
                }
            }
    }

    @ViewBuilder
    var toastView: some View {
        switch position {
        case .top:
            ToastView(message: message)
                .transition(.move(edge: .top).combined(with: .opacity))
        case .center:
            ToastView(message: message)
                .transition(.opacity)
        case .bottom:
            ToastView(message: message)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, duration: Double = 2, position: ToastModifier.Position = .center) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, duration: duration, position: position))
    }
}
