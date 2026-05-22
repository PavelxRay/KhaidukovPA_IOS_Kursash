//
//  StorageManager.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import Foundation

class StorageManager {
    static let shared = StorageManager()
    private init() {}
    
    // Получаем путь к системной папке Documents приложения
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Формируем локальный путь для файла книги по её ID
    func getLocalFileURL(for bookId: Int) -> URL {
        return documentsDirectory.appendingPathComponent("book_\(bookId).epub")
    }
    
    // Проверяем, скачан ли файл локально
    func isBookDownloaded(bookId: Int) -> Bool {
        let fileURL = getLocalFileURL(for: bookId)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // Скачивание файла по URL-строке из API Gutendex
    func downloadBook(bookId: Int, urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let localURL = getLocalFileURL(for: bookId)
        
        // Если файл уже есть, просто возвращаем его путь
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        
        // Скачиваем файл во временную директорию через URLSession
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        // Перемещаем файл из временной папки в постоянную папку Documents
        try FileManager.default.moveItem(at: temporaryURL, to: localURL)
        return localURL
    }
}
