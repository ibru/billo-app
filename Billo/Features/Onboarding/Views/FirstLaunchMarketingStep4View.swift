//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchMarketingStep4View: View {
    let onContinue: () -> Void

    var body: some View {
        FirstLaunchMarketingStepTemplateView(
            systemImage: "checkmark.seal",
            title: "Feel in control again",
            subtitle: "Track what’s paid, what’s coming, and what’s already handled.",
            continueTitle: "Continue",
            onContinue: onContinue
        )
    }
}

#Preview {
    FirstLaunchMarketingStep4View(onContinue: {})
}

