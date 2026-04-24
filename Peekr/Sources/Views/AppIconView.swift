import SwiftUI

/// Render this view at 1024×1024 in the simulator, screenshot it, then drop
/// the PNG into AppIcon.appiconset/AppIcon-1024.png.
/// Temporarily set this as the root view in ContentView to see it full screen.
struct AppIconView: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.10, blue: 0.22),
                        Color(red: 0.04, green: 0.06, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Rack enclosure
                RoundedRectangle(cornerRadius: s * 0.055)
                    .fill(Color(red: 0.10, green: 0.14, blue: 0.26))
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.055)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                    )
                    .frame(width: s * 0.72, height: s * 0.68)
                    .shadow(color: .black.opacity(0.5), radius: s * 0.04)

                // Rack units
                VStack(spacing: s * 0.038) {
                    rackUnit(s: s, dotColor: Color(red: 0.2, green: 0.9, blue: 0.4))
                    rackUnit(s: s, dotColor: Color(red: 0.2, green: 0.9, blue: 0.4))
                    rackUnit(s: s, dotColor: Color(red: 1.0, green: 0.65, blue: 0.0))
                    rackUnit(s: s, dotColor: Color(red: 0.95, green: 0.25, blue: 0.25))
                }
            }
        }
        .ignoresSafeArea()
    }

    private func rackUnit(s: CGFloat, dotColor: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.025)
                .fill(Color(red: 0.14, green: 0.20, blue: 0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.025)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )

            HStack(spacing: 0) {
                // Left edge accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(dotColor.opacity(0.7))
                    .frame(width: s * 0.012, height: s * 0.065)
                    .padding(.leading, s * 0.03)

                // Drive slots
                HStack(spacing: s * 0.018) {
                    ForEach(0..<4) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.09, green: 0.13, blue: 0.24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .frame(width: s * 0.055, height: s * 0.065)
                    }
                }
                .padding(.leading, s * 0.03)

                Spacer()

                // Status LED
                Circle()
                    .fill(dotColor)
                    .frame(width: s * 0.036, height: s * 0.036)
                    .shadow(color: dotColor.opacity(0.9), radius: s * 0.022)
                    .padding(.trailing, s * 0.045)
            }
        }
        .frame(width: s * 0.62, height: s * 0.10)
    }
}

#Preview {
    AppIconView()
        .frame(width: 1024, height: 1024)
}
