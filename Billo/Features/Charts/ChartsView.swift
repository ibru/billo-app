//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

struct ChartsView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "Charts"),
            systemImage: "chart.bar",
            description: Text(String(localized: "Coming soon"))
        )
        .navigationTitle(String(localized: "Charts"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChartsView()
    }
}

