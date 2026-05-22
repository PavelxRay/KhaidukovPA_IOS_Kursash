//
//  NetworkManager.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Неверный URL-адрес."
        case .noData: return "Данные не получены."
        case .decodingError: return "Ошибка обработки данных."
        case .serverError: return "Ошибка сервера. Проверьте сеть."
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    func fetchBooks(query: String = "") async throws -> [Book] {
        var urlString = "https://gutendex.com/books"
        if !query.isEmpty {
            // Кодируем пробелы и спецсимволы в строке поиска
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?search=\(encodedQuery)"
            }
        }
        
        guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NetworkError.serverError
            }
            let decodedResponse = try JSONDecoder().decode(GutendexResponse.self, from: data)
            return decodedResponse.results
        } catch {
            throw NetworkError.decodingError
        }
    }

}
