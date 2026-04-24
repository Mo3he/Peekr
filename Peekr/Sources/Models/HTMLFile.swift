import SwiftUI
import UniformTypeIdentifiers

/// Wraps an HTML Data payload so it can be shared via ShareLink as an .html file.
struct HTMLFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .html) { file in
            file.data
        }
    }
}
