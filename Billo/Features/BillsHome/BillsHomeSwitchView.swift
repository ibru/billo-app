//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct BillsHomeSwitchView: View {
    @AppStorage("billsDefaultView") private var viewModeRawValue: String = BillsHomeViewMode.list.rawValue

    private var viewModeBinding: Binding<BillsHomeViewMode> {
        Binding {
            BillsHomeViewMode(rawValue: viewModeRawValue) ?? .list
        } set: { newValue in
            viewModeRawValue = newValue.rawValue
        }
    }

    var body: some View {
        switch viewModeBinding.wrappedValue {
        case .list:
            BillsListView(viewMode: viewModeBinding)
        case .calendar:
            BillsCalendarView(viewMode: viewModeBinding)
        }
    }
}
