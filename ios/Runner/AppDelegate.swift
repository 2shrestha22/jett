import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, JettApi {
    let userDefaults = UserDefaults(suiteName: "group.jett")

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        let controller = window?.rootViewController as! FlutterViewController
        JettApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func getPlatformVersion() throws -> Version {
        var version = Version()
        version.string = "iOS " + UIDevice.current.systemVersion
        return version
    }

    func getInitialFiles() throws -> [PlatformFile] {
        guard let data = userDefaults?.data(forKey: "files"),
            let files = try? JSONDecoder().decode([CodableFile].self, from: data)
        else {
            return []
        }
        userDefaults?.removeObject(forKey: "files")
        return files.map { PlatformFile(uri: $0.uri, name: $0.name, size: $0.size) }
    }

    func getAPKs(withSystemApp: Bool) throws -> [APKInfo] {
        return []
    }

}
