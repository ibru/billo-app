//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

struct DataExportView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "Data Export"),
            systemImage: "square.and.arrow.up",
            description: Text(String(localized: "Coming soon"))
        )
        .navigationTitle(String(localized: "Data Export"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}

