//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchMarketingStep2View: View {
    let onContinue: () -> Void

    var body: some View {
        FirstLaunchMarketingStepTemplateView(
            systemImage: "bell.badge",
            title: "Never miss a due date",
            subtitle: "Know what’s due this week and this month at a glance.",
            continueTitle: "Continue",
            onContinue: onContinue
        )
    }
}

#Preview {
    FirstLaunchMarketingStep2View(onContinue: {})
}

