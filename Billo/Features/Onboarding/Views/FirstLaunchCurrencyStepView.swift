//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchCurrencyStepView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel

    let onContinue: () -> Void

    var body: some View {
        CurrencyOnboardingView()
            .onChange(of: appSettingsModel.currencyCode) { _, newValue in
                guard newValue != nil else { return }
                onContinue()
            }
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let preview = BilloPreviewContainer.empty()
    return FirstLaunchCurrencyStepView(onContinue: {})
        .environment(preview.appSettingsModel)
}
#endif

