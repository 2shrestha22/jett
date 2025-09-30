import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, JettHostApi {
    let userDefaults = UserDefaults(suiteName: "group.jett")
    var initialFiles: [PlatformFile] = []
    let eventListener = EventListener()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        JettHostApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: self)
        FilesStreamHandler.register(with: controller.binaryMessenger, streamHandler: eventListener)

        handleSharedFiles(setInitialFiles: true)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if url.scheme == "jett" && url.host == "share" {
            // matches jett://share received from share extension
            handleSharedFiles(setInitialFiles: false)
            return true
        }
        return false
    }

    func handleSharedFiles(setInitialFiles: Bool) {
        let platformFiles = getSharedPlatformFiles()
        if setInitialFiles {
            self.initialFiles = platformFiles
        } else {
            eventListener.onEvent(files: platformFiles)
        }
    }

    func getInitialFiles() -> [PlatformFile] {
        let tempFiles = initialFiles
        initialFiles = []

        return tempFiles
    }

    func getSharedPlatformFiles() -> [PlatformFile] {
        guard let data = userDefaults?.data(forKey: "files"),
            let files = try? JSONDecoder().decode([CodableFile].self, from: data)
        else {
            return []
        }
        userDefaults?.removeObject(forKey: "files")
        return files.map { PlatformFile(uri: $0.uri, name: $0.name, size: $0.size) }
    }

    func getAPKs(withSystemApp: Bool) throws -> [APKInfo] {
        // iOS can't have this
        return []
    }

    func getPlatformVersion() throws -> Version {
        var version = Version()
        version.string = "iOS " + UIDevice.current.systemVersion
        return version
    }

}
