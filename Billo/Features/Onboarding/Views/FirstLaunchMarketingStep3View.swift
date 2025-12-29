//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchMarketingStep3View: View {
    let onContinue: () -> Void

    var body: some View {
        FirstLaunchMarketingStepTemplateView(
            systemImage: "square.grid.2x2",
            title: "Replace scattered reminders",
            subtitle: "No more spreadsheets, email digging, or noisy calendar alerts.",
            continueTitle: "Continue",
            onContinue: onContinue
        )
    }
}

#Preview {
    FirstLaunchMarketingStep3View(onContinue: {})
}

