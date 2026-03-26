import Foundation
import SwiftUI
import Combine

final class ShelfModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var lastDropSuccess: Bool = false
    
    func add(urls: [URL]) {
        for url in urls {
            if !files.contains(url) {
                files.append(url)
            }
        }
    }
    
    func remove(at offsets: IndexSet) {
        files.remove(atOffsets: offsets)
    }

    func remove(url: URL) {
        if let idx = files.firstIndex(of: url) {
            files.remove(at: idx)
        }
    }
    
    func triggerSuccess() {
        DispatchQueue.main.async {
            self.lastDropSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.lastDropSuccess = false
            }
        }
    }
}
