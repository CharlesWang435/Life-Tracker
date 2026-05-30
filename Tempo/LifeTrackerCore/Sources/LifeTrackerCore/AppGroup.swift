import Foundation

public enum AppGroup {
    public static let identifier = "group.com.charleswang.lifetracker"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
