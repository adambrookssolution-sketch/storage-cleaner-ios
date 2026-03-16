import SwiftUI

/// Dashboard top bar: app name + gear icon for settings
struct DashboardHeaderView: View {
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack {
            Text(AppConstants.AppInfo.appName)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Spacer()

            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ColorTokens.secondaryText)
            }
        }
        .padding(.horizontal, AppConstants.UI.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
