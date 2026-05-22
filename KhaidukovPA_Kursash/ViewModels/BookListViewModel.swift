//
//  BookListViewModel.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//
//
//  BookListViewModel.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import Foundation
import Combine

// Перечисление всех состояний экрана для курсовой работы
enum ScreenState {
    case idle
    case loading
    case success(books: [Book])
    case error(message: String)
}

@MainActor
class BookListViewModel: ObservableObject {
    // Опубликованное свойство, за которым будет следить наш интерфейс (View)
    @Published var state: ScreenState = .idle
    
    // Переменная, которая будет хранить текст, вводимый пользователем в строку поиска
    @Published var searchText: String = ""
    
    private let networkManager = NetworkManager.shared
    
    // Асинхронная функция загрузки книг с опциональным параметром поискового запроса
    func loadBooks(query: String = "") async {
        state = .loading
        
        do {
            // Передаем строку поиска в сетевой менеджер
            let fetchedBooks = try await networkManager.fetchBooks(query: query)
            
            if fetchedBooks.isEmpty {
                state = .error(message: "По вашему запросу ничего не найдено.")
            } else {
                state = .success(books: fetchedBooks)
            }
        } catch let error as NetworkError {
            state = .error(message: error.localizedDescription)
        } catch {
            state = .error(message: "Непредвиденная ошибка: \(error.localizedDescription)")
        }
    }
}
