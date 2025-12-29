//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchMarketingStep1View: View {
    let onContinue: () -> Void

    var body: some View {
        FirstLaunchMarketingStepTemplateView(
            systemImage: "calendar.badge.clock",
            title: "Stop bill anxiety",
            subtitle: "One calm place to answer: “What’s due next?”",
            continueTitle: "Continue",
            onContinue: onContinue
        )
    }
}

#Preview {
    FirstLaunchMarketingStep1View(onContinue: {})
}

