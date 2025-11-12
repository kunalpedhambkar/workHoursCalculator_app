//
//  SplashView.swift
//  Work Hours Calculator
//
//  Created by Kunal Rajesh Pedhambkar on 7/11/2025.
//


import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0
    @Environment(\.colorScheme) private var colorScheme

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }

    private var tileColor: Color {
        colorScheme == .dark ? .white : .black
    }

    /// Prefer an asset named "AppLogo" that matches your app icon.
    /// Falls back to an SF Symbol if the asset isn’t present.
    private func appLogoImage() -> Image {
        #if canImport(UIKit)
        if let ui = UIImage(named: "AppLogo") { // Use a separate Image Set named "AppLogo"
            return Image(uiImage: ui)
        } else {
            #if DEBUG
            print("[Splash] ⚠️ 'AppLogo' image asset not found. Falling back to SF Symbol.")
            #endif
        }
        #endif
        return Image(systemName: "app.fill")
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                appLogoImage()
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72) // inner icon size
                    .padding(12) // makes the total square 96x96
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(tileColor) // square background (white in dark mode, black in light mode)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) // subtle border
                    )

                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .tracking(0.5)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // fade + scale in
                withAnimation(.easeOut(duration: 0.7)) {
                    opacity = 1
                    scale = 1.0
                }
                // subtle bounce
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        scale = 1.04
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            scale = 1.0
                        }
                    }
                }
            }
        }
    }
}
