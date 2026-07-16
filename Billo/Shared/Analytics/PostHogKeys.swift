//  Created by Jiri Urbasek on 07/10/26.

enum PostHogKeys {
    #if DEBUG
    // Analytics disabled in debug by default; set BILLO_ENABLE_ANALYTICS=1 to test
    static let projectToken = "__no_analytics_in_debug_mode__"
    #else
    static let projectToken = "phc_pWs6A6Rt7qyunTkaawE7kdpSdhhkc3FgFWPKZKJcTHEy"
    #endif
    static let host = "https://us.i.posthog.com"
}
