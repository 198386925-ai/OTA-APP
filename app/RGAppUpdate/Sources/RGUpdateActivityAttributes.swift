// MARK: LUIYo — Live Activity payload for an in-progress update.
//
// Self-contained ActivityKit definition (this used to come from a
// host-app module). The widget extension target that renders the
// activity must include this same file: app and extension must
// agree on the attributes and content-state shape or the system
// cannot match the running activity to its UI.
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct RGUpdateActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var phase: String
        /// Pre-localized label for the current phase.
        public var label: String
        /// Pre-localized label for the open-app action.
        public var action: String
        /// Pre-localized label shown when the activity goes stale.
        public var staleLabel: String
        public var downloaded: Int64
        public var total: Int64

        public var fraction: Double {
            total > 0 ? min(1, Double(downloaded) / Double(total)) : 0
        }

        public init(phase: String, label: String, action: String, staleLabel: String, downloaded: Int64, total: Int64) {
            self.phase = phase
            self.label = label
            self.action = action
            self.staleLabel = staleLabel
            self.downloaded = downloaded
            self.total = total
        }
    }

    public var build: Int64
    public var version: String
    public var title: String
    /// Deep link back into the app's update settings.
    public var updateURL: URL

    public init(build: Int64, version: String, title: String, updateURL: URL) {
        self.build = build
        self.version = version
        self.title = title
        self.updateURL = updateURL
    }
}
