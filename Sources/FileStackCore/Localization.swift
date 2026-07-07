import Foundation

/// Central localization accessor. The app sets `Localization.bundle` to
/// `Bundle.module` at launch so that `NSLocalizedString` look-ups resolve
/// against the embedded `Localizable.strings` files regardless of whether
/// the code lives in FileStackCore or FileStackApp.
public enum Localization {
    /// The bundle used for all `NSLocalizedString` look-ups.
    /// Defaults to `Bundle.main`; the host application should override this
    /// to `Bundle.module` (or the appropriate resource bundle) early in launch.
    public static var bundle: Bundle = .main

    /// Returns the localized string for `key` in the current `bundle`.
    public static func string(_ key: String, _ comment: String = "") -> String {
        NSLocalizedString(key, bundle: bundle, comment: comment)
    }

    /// Returns a localized format string with the given arguments.
    public static func string(_ key: String, _ comment: String = "", arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: bundle, comment: comment)
        return String(format: format, arguments: arguments)
    }
}