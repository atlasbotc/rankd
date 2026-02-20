import SwiftData

extension ModelContext {
    /// Save with error logging instead of silently swallowing failures.
    func safeSave(file: String = #file, line: Int = #line) {
        do {
            try save()
        } catch {
            print("⚠️ SwiftData save failed at \(file):\(line): \(error)")
        }
    }
}
