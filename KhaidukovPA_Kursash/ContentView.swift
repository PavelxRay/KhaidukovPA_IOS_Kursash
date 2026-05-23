import SwiftUI

struct ContentView: View {
    @StateObject private var catalogViewModel = BookListViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        // Современный контейнер вкладок iOS
        TabView(selection: $selectedTab) {
            
            // Вкладка 1: Твоя Локальная Библиотека
            LocalLibraryView()
                .tabItem {
                    Label("Библиотека", systemImage: "books.vertical.fill")
                }
                .tag(0)
            
            // Вкладка 2: Онлайн каталог (Gutendex)
            NavigationStack {
                Group {
                    switch catalogViewModel.state {
                    case .idle:
                        Color.clear.onAppear { Task { await catalogViewModel.loadBooks() } }
                    case .loading:
                        ProgressView("Загрузка...")
                    case .success(let books):
                        List(books, id: \.id) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title).font(.headline).lineLimit(2)
                                    Text(book.authorName).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                    case .error(let message):
                        Button("Повторить") { Task { await catalogViewModel.loadBooks(query: catalogViewModel.searchText) } }
                    }
                }
                .navigationTitle("Облако")
                .searchable(text: $catalogViewModel.searchText, prompt: "Поиск в сети")
                .onSubmit(of: .search) { Task { await catalogViewModel.loadBooks(query: catalogViewModel.searchText) } }
            }
            .tabItem {
                Label("Поиск", systemImage: "cloud.bubble.fill")
            }
            .tag(1)
        }
        .accentColor(.blue) // Цвет активной вкладки
    }
}
