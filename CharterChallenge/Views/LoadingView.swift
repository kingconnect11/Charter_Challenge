import SwiftUI
import UIKit

struct LoadingView: View {
    @Binding var progress: Double
    let title: String
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background Image
            // Add your image to Assets.xcassets and name it "LoadingBackground"
            if let _ = UIImage(named: "LoadingBackground") {
                Image("LoadingBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.9)
            } else {
                // Fallback gradient background if image not found
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Dark overlay for better text visibility
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Title
                Text(title)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                
                // Progress Bar Container
                VStack(spacing: 12) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 12)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 12)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 12)
                    .frame(maxWidth: 280)
                    
                    // Percentage Text
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 100)
            }
            .opacity(opacity)
        }
        .onAppear {
            // Fade in effect
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
        }
    }
}

