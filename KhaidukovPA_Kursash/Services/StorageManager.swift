import Foundation

class StorageManager {
    static let shared = StorageManager()
    private init() {}
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func getLocalFileURL(for bookId: Int) -> URL {
        return documentsDirectory.appendingPathComponent("book_\(bookId).epub")
    }

    
    // Проверяем, что файл не просто существует, но и весит больше 100 байт (не пустой)
    func isBookDownloaded(bookId: Int) -> Bool {
        let fileURL = getLocalFileURL(for: bookId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attributes[.size] as? Int64 {
            return size > 100
        }
        return false
    }
    
    func downloadBook(bookId: Int, urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let localURL = getLocalFileURL(for: bookId)
        
        if isBookDownloaded(bookId: bookId) {
            return localURL
        }
        
        // Если лежал старый пустой/битый файл — удаляем его перед новой закачкой
        try? FileManager.default.removeItem(at: localURL)
        
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        try FileManager.default.moveItem(at: temporaryURL, to: localURL)
        return localURL
    }
}
