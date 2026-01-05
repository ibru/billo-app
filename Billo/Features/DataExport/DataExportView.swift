//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

	struct DataExportView: View {
	    var body: some View {
	        ContentUnavailableView(
	            "Data Export",
	            systemImage: "square.and.arrow.up",
	            description: Text("Coming soon")
	        )
	        .navigationTitle("Data Export")
	        .platformInlineNavigationTitle()
	    }
	}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
