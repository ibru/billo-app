//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

	struct ChartsView: View {
	    var body: some View {
	        ContentUnavailableView(
	            "Charts",
	            systemImage: "chart.bar",
	            description: Text("Coming soon")
	        )
	        .navigationTitle("Charts")
	        .platformInlineNavigationTitle()
	    }
	}

#Preview {
    NavigationStack {
        ChartsView()
    }
}
