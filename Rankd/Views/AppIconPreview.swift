import SwiftUI

/// Preview-only view that renders the app icon design.
/// Screenshot this at 1024×1024 to use as the actual App Store icon asset.
///
/// Design:
/// - Background: brand slate blue (#596F94)
/// - Foreground: white "R" in bold serif-style font, centered
/// - iOS applies corner masking automatically
#Preview("App Icon – 1024×1024") {
    ZStack {
        // Brand background
        RankdColors.brand
        
        Text("R")
            .font(.system(size: 500, weight: .bold, design: .serif))
            .foregroundStyle(.white)
    }
    .frame(width: 1024, height: 1024)
    .clipped()
}
