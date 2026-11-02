// MARK: LUIYo — string resolution for the update module.
//
// Replaces the host app's string-table service: keys are resolved
// for an explicit language code from the host app's own .lproj
// bundles (Bundle.main), falling back to the default localization
// and finally to the key itself, so an untranslated host still
// shows a stable identifier instead of a blank label.
import Foundation

enum RGUpdateStrings {
    static func string(_ key: String, language: String) -> String {
        if !language.isEmpty,
           let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        let value = NSLocalizedString(key, comment: "")
        return value
    }
}
