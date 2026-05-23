import SwiftUI

struct ContentView: View {
    @StateObject private var catalogViewModel = BookListViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Вкладка 1: Локальная Библиотека
            LocalLibraryView()
                .tabItem {
                    Label("Библиотека", systemImage: "books.vertical.fill")
                }
                .tag(0)
            
            // Вкладка 2: Онлайн каталог
            NavigationStack {
                ZStack {
                    switch catalogViewModel.state {
                    case .idle:
                        Color.clear
                            .onAppear {
                                Task {
                                    await catalogViewModel.loadBooks()
                                }
                            }
                    case .loading:
                        // Показываем большой лоадер ТОЛЬКО если список книг пуст (первый запуск)
                        if catalogViewModel.searchText.isEmpty {
                            ProgressView("Загрузка каталога")
                        } else {
                            // Если пользователь что-то ищет, не блокируем экран белым фоном,
                            // а оставляем интерфейс отзывчивым
                            Color.clear
                        }
                    case .success(let books):
                        List(books, id: \.id) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(book.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(book.authorName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .listStyle(.plain)
                    case .error(let message):
                        VStack(spacing: 16) {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Повторить поиск") {
                                Task {
                                    await catalogViewModel.loadBooks(query: catalogViewModel.searchText)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .navigationTitle("Каталог")
                .searchable(text: $catalogViewModel.searchText, prompt: "Поиск книги в сети")
                // ИСПРАВЛЕНО: Отслеживаем ввод текста в строку поиска «на лету»
                .onChange(of: catalogViewModel.searchText) { newValue in
                    Task {
                        // Вызываем сетевой поиск при каждом изменении текста
                        await catalogViewModel.loadBooks(query: newValue)
                    }
                }
                // Маленький лоадер в углу крутится ТОЛЬКО когда идет фоновый поиск по тексту
                .toolbar {
                    if case .loading = catalogViewModel.state, !catalogViewModel.searchText.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ProgressView()
                        }
                    }
                }
            }
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            .tag(1)
        }
        .tint(.blue)
    }
}
