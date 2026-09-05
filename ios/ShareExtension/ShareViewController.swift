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
            group.enter()
            loadFile(from: attachment) { file in
                if let file = file {
                    files.append(file)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.userDefaults?.set(try? JSONEncoder().encode(files), forKey: "files")
            self.openHostApp()
        }
    }

    private func loadFile(
        from attachment: NSItemProvider,
        completion: @escaping (CodableFile?) -> Void
    ) {
        // Prefer a direct file URL if the provider has one (Files app, etc.)
        if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                if let url = item as? URL, let copyUrl = self.copyFile(url: url) {
                    completion(CodableFile(uri: copyUrl, name: url.lastPathComponent))
                } else {
                    // fall back below if this somehow fails
                    self.loadViaFileRepresentation(attachment, completion: completion)
                }
            }
            return
        }

        loadViaFileRepresentation(attachment, completion: completion)
    }

    private func loadViaFileRepresentation(
        _ attachment: NSItemProvider,
        completion: @escaping (CodableFile?) -> Void
    ) {
        // Find the most specific type identifier the provider actually offers
        guard let typeIdentifier = attachment.registeredTypeIdentifiers.first else {
            completion(nil)
            return
        }

        attachment.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { tempUrl, error in
            guard let tempUrl = tempUrl else {
                if let error = error {
                    NSLog("loadFileRepresentation failed: \(error.localizedDescription)")
                }
                completion(nil)
                return
            }
            // tempUrl is only valid inside this closure — copy synchronously now
            let copyUrl = self.copyFile(url: tempUrl)
            if let copyUrl = copyUrl {
                completion(CodableFile(uri: copyUrl, name: tempUrl.lastPathComponent))
            } else {
                completion(nil)
            }
        }
    }

    private func openHostApp() {
        let url = URL(string: "jett://share")!

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
