import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, JettHostApi {
    let userDefaults = UserDefaults(suiteName: "group.jett")
    var initialFiles: [PlatformFile] = []
    let eventListener = EventListener()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let messenger = engineBridge.applicationRegistrar.messenger()
        JettHostApiSetup.setUp(binaryMessenger: messenger, api: self)
        FilesStreamHandler.register(with: messenger, streamHandler: eventListener)

        handleSharedFiles(setInitialFiles: true)
    }

    // Handles jett://share received from the share extension.
    // Called from SceneDelegate since UIScene lifecycle no longer
    // delivers URLs to application(_:open:options:).
    func handleSharedURL(_ url: URL) -> Bool {
        if url.scheme == "jett" && url.host == "share" {
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
