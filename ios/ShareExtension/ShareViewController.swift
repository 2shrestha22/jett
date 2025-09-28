//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sangam Shrestha on 13/09/2025.
//

import Social
import UIKit
import UniformTypeIdentifiers

let groupId = "group.jett"

class ShareViewController: UIViewController {
    let userDefaults = UserDefaults(suiteName: groupId)

    override func viewDidLoad() {
        super.viewDidLoad()
        processAttachments()
    }

    private func processAttachments() {
        guard let extensionContext = extensionContext,
            let inputItems = extensionContext.inputItems as? [NSExtensionItem],
            let firstItem = inputItems.first,
            let attachments = firstItem.attachments
        else {
            self.openHostApp()
            return
        }

        var files: [CodableFile] = []
        let group = DispatchGroup()

        for attachment in attachments {
            let hasFileUrl = attachment.hasItemConformingToTypeIdentifier(
                UTType.fileURL.identifier
            )
            if hasFileUrl {
                group.enter()
                attachment.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier
                ) { (item, error: Error?) in
                    if let url = item as? URL {
                        NSLog("URL:", url.absoluteString)
                        if let copyUrl = self.copyFile(url: url) {
                            files.append(CodableFile(uri: copyUrl, name: url.lastPathComponent))
                        }
                    } else if let error = error {
                        print(
                            "Failed to load item: \(error.localizedDescription)"
                        )
                    }
                    group.leave()

                }
            }
        }
        group.notify(queue: .main) {
            self.userDefaults?.set(try? JSONEncoder().encode(files), forKey: "files")
            self.openHostApp()
        }
    }

    private func openHostApp() {
        let url = URL(string: "share://com.sangamshrestha.jett")!

        var responder: UIResponder? = self
        while responder != nil {
            if let app = responder as? UIApplication {
                app.open(url) { success in
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
                return
            }
            responder = responder?.next
        }
        self.extensionContext?.completeRequest(returningItems: nil)
    }

    private func copyFile(url: URL) -> String? {
        let dstFileName = generateRandomNameForFile(url: url)
        let dstPath = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
        )!.appendingPathComponent(dstFileName)

        do {
            try FileManager.default.copyItem(at: url, to: dstPath)
            return dstPath.absoluteString
        } catch (let error) {
            NSLog("Failed to copy file", error.localizedDescription)
            return nil
        }

    }

    private func generateRandomNameForFile(url: URL) -> String {
        return UUID().uuidString + "." + url.pathExtension
    }
    
}
