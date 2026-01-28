import Foundation

// MARK: - Data Models

struct LetterboxdEntry: Identifiable {
    let id = UUID()
    let name: String
    let year: String?
    let rating: Double?
    let letterboxdURI: String?
    let date: String?
    
    var tier: Tier? {
        guard let rating else { return nil }
        switch rating {
        case 4.0...5.0: return .good
        case 2.5..<4.0: return .medium
        case 0.5..<2.5: return .bad
        default: return nil
        }
    }
    
    var starDisplay: String {
        guard let rating else { return "Unrated" }
        let fullStars = Int(rating)
        let halfStar = rating.truncatingRemainder(dividingBy: 1.0) >= 0.5
        var result = String(repeating: "★", count: fullStars)
        if halfStar { result += "½" }
        return result
    }
}

enum LetterboxdCSVType {
    case ratings    // Date,Name,Year,Letterboxd URI,Rating
    case watched    // Date,Name,Year,Letterboxd URI
    case diary      // Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
    case watchlist  // Date,Name,Year,Letterboxd URI
    case unknown
}

enum LetterboxdImportError: Error, LocalizedError {
    case fileReadFailed
    case emptyFile
    case noValidEntries
    case malformedCSV(String)
    case unrecognizedFormat
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "Couldn't read the file. Make sure it's a valid CSV file."
        case .emptyFile:
            return "The file is empty. Please select a CSV file with data."
        case .noValidEntries:
            return "No valid entries found. Make sure this is a Letterboxd export file."
        case .malformedCSV(let detail):
            return "The CSV file appears malformed: \(detail)"
        case .unrecognizedFormat:
            return "Unrecognized file format. Please use ratings.csv, watched.csv, diary.csv, or watchlist.csv from your Letterboxd export."
        }
    }
}

// MARK: - CSV Parser

struct LetterboxdImporter {
    
    /// Parse a Letterboxd CSV file from a URL (e.g., from file picker)
    static func parse(url: URL) throws -> [LetterboxdEntry] {
        guard url.startAccessingSecurityScopedResource() else {
            throw LetterboxdImportError.fileReadFailed
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            throw LetterboxdImportError.fileReadFailed
        }
        
        return try parse(csv: content)
    }
    
    /// Parse a CSV string
    static func parse(csv: String) throws -> [LetterboxdEntry] {
        let trimmed = csv.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LetterboxdImportError.emptyFile
        }
        
        let rows = parseCSVRows(trimmed)
        guard rows.count > 1 else {
            throw LetterboxdImportError.emptyFile
        }
        
        let header = rows[0]
        let csvType = detectCSVType(header: header)
        
        guard csvType != .unknown else {
            throw LetterboxdImportError.unrecognizedFormat
        }
        
        let columnMap = buildColumnMap(header: header)
        
        guard columnMap["Name"] != nil else {
            throw LetterboxdImportError.malformedCSV("Missing 'Name' column")
        }
        
        var entries: [LetterboxdEntry] = []
        
        for i in 1..<rows.count {
            let fields = rows[i]
            guard !fields.isEmpty, fields.contains(where: { !$0.isEmpty }) else { continue }
            
            let name = safeField(fields, index: columnMap["Name"])
            guard !name.isEmpty else { continue }
            
            let year = safeField(fields, index: columnMap["Year"])
            let ratingStr = safeField(fields, index: columnMap["Rating"])
            let uri = safeField(fields, index: columnMap["Letterboxd URI"])
            
            // Use "Watched Date" for diary, otherwise "Date"
            let date = safeField(fields, index: columnMap["Watched Date"])
                .isEmpty ? safeField(fields, index: columnMap["Date"]) : safeField(fields, index: columnMap["Watched Date"])
            
            let rating: Double? = ratingStr.isEmpty ? nil : Double(ratingStr)
            
            entries.append(LetterboxdEntry(
                name: name,
                year: year.isEmpty ? nil : year,
                rating: rating,
                letterboxdURI: uri.isEmpty ? nil : uri,
                date: date.isEmpty ? nil : date
            ))
        }
        
        guard !entries.isEmpty else {
            throw LetterboxdImportError.noValidEntries
        }
        
        // Deduplicate by name+year (diary can have rewatches)
        var seen = Set<String>()
        var unique: [LetterboxdEntry] = []
        for entry in entries {
            let key = "\(entry.name)|\(entry.year ?? "")"
            if seen.insert(key).inserted {
                unique.append(entry)
            }
        }
        
        return unique
    }
    
    // MARK: - CSV Type Detection
    
    static func detectCSVType(header: [String]) -> LetterboxdCSVType {
        let normalized = Set(header.map { $0.trimmingCharacters(in: .whitespaces) })
        
        if normalized.contains("Rating") && normalized.contains("Watched Date") && normalized.contains("Rewatch") {
            return .diary
        }
        if normalized.contains("Rating") && normalized.contains("Name") {
            return .ratings
        }
        if normalized.contains("Name") && normalized.contains("Year") && !normalized.contains("Rating") {
            // Could be watched or watchlist — both have same columns
            return .watched
        }
        if normalized.contains("Name") {
            return .watched
        }
        return .unknown
    }
    
    // MARK: - CSV Parsing Helpers
    
    /// Parse CSV content into rows of fields, handling quoted fields properly
    private static func parseCSVRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var inQuotes = false
        let chars = Array(content)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if inQuotes {
                if char == "\"" {
                    // Check for escaped quote ("")
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                    continue
                }
            }
            
            switch char {
            case "\"":
                inQuotes = true
            case ",":
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            case "\r":
                // Handle \r\n or standalone \r
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                rows.append(currentRow)
                currentRow = []
                if i + 1 < chars.count && chars[i + 1] == "\n" {
                    i += 1
                }
            case "\n":
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                rows.append(currentRow)
                currentRow = []
            default:
                currentField.append(char)
            }
            
            i += 1
        }
        
        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private static func buildColumnMap(header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, col) in header.enumerated() {
            map[col.trimmingCharacters(in: .whitespaces)] = index
        }
        return map
    }
    
    private static func safeField(_ fields: [String], index: Int?) -> String {
        guard let idx = index, idx < fields.count else { return "" }
        return fields[idx]
    }
}
