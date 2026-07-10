//  Created by Jiri Urbasek on 07/10/26.

enum PostHogKeys {
    #if DEBUG
    // Analytics disabled in debug by default; set BILLO_ENABLE_ANALYTICS=1 to test
    static let projectToken = "__no_analytics_in_debug_mode__"
    #else
    // TODO: Create the Billo PostHog project and paste the real token before release.
    static let projectToken = "__billo_posthog_token__"
    #endif
    static let host = "https://us.i.posthog.com"
}
