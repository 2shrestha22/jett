//
//  PlatformFile.swift
//  Runner
//
//  Created by Sangam Shrestha on 22/09/2025.
//

import Foundation

struct CodableFile: Codable {
    let uri: String
    let name: String?
    let size: Int64?

    init(uri: String, name: String? = nil, size: Int64? = nil) {
        self.uri = uri
        self.name = name
        self.size = size
    }
}
