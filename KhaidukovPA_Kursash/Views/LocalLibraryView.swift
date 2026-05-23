import SwiftUI
import EPUBKit

// Структура находится на глобальном уровне (вне View) — это правильно!
struct LocalBookIdentifiable: Identifiable {
    let id: Int
    let title: String
    let author: String
    let fileURL: URL
    let coverData: Data?
}

struct LocalLibraryView: View {
    @State private var localBooks: [LocalBookIdentifiable] = []
    
    // Вычисляемые свойства для верхней панели статистики
    private var totalBooksCount: Int { localBooks.count }
    
    private var completedBooksCount: Int {
        localBooks.filter { getProgressPercentage(for: $0) >= 100 }.count
    }
    
    private var currentlyReadingCount: Int {
        localBooks.filter {
            let percent = getProgressPercentage(for: $0)
            return percent > 0 && percent < 100
        }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Панель статистики
                if !localBooks.isEmpty {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Всего книг").font(.caption).foregroundColor(.secondary)
                            Text("\(totalBooksCount)").font(.title3).bold()
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Читаю").font(.caption).foregroundColor(.secondary)
                            Text("\(currentlyReadingCount)").font(.title3).bold().foregroundColor(.blue)
                        }
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Прочитано").font(.caption).foregroundColor(.secondary)
                            Text("\(completedBooksCount)").font(.title3).bold().foregroundColor(.green)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
                
                // Список книг
                if localBooks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Библиотека пуста")
                            .font(.headline)
                        Text("Перейдите на вкладку 'Поиск', чтобы найти и скачать свои первые книги.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 100)
                    Spacer()
                } else {
                    List {
                        ForEach(localBooks) { book in
                            NavigationLink(destination: ReaderView(bookTitle: book.title, fileURL: book.fileURL, bookId: book.id)) {
                                HStack(spacing: 16) {
                                    if let coverData = book.coverData, let uiImage = UIImage(data: coverData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 80)
                                            .cornerRadius(8)
                                            .clipped()
                                    } else {
                                        Image(systemName: "book.closed.fill")
                                            .font(.system(size: 24))
                                            .frame(width: 60, height: 80)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(book.title).font(.headline).lineLimit(2)
                                        Text(book.author).font(.subheadline).foregroundColor(.secondary)
                                        
                                        let progressPercent = getProgressPercentage(for: book)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            ProgressView(value: progressPercent / 100.0)
                                                .progressViewStyle(LinearProgressViewStyle(tint: progressPercent >= 100 ? .green : .blue))
                                            Text(progressPercent >= 100 ? "Прочитано! 🎉" : "Прочитано: \(Int(progressPercent))%")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteBook)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Моя библиотека")
            .onAppear {
                reloadLocalBooks()
            }
        }
    } // Конец body
    
    // ВСЕ ФУНКЦИИ ДОЛЖНЫ ЛЕЖАТЬ ВНУТРИ LOCALLIBRARYVIEW
    private func getProgressPercentage(for book: LocalBookIdentifiable) -> Double {
        let savedPage = StorageManager.shared.getProgress(bookId: book.id)
        
        // Читаем точный сохраненный объем книги из кэша
        let totalPages = UserDefaults.standard.integer(forKey: "book_total_pages_\(book.id)")
        
        // Если книгу еще ни разу не открывали, общего числа страниц в кэше нет (totalPages == 0)
        guard totalPages > 0 else {
            return 0.0
        }
        
        // Так как savedPage начинается с 0 (индекс массива), для расчета прогресса
        // завершенной страницы используем (savedPage + 1)
        let progress = (Double(savedPage + 1) / Double(totalPages)) * 100.0
        
        return min(max(progress, 0.0), 100.0)
    }
    
    private func reloadLocalBooks() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let epubURLs = fileURLs.filter { $0.pathExtension == "epub" }
            var loadedBooks: [LocalBookIdentifiable] = []
            
            for url in epubURLs {
                let filename = url.deletingPathExtension().lastPathComponent
                let rawId = filename.replacingOccurrences(of: "book_", with: "")
                let bookId = Int(rawId) ?? Int(Date().timeIntervalSince1970)
                
                if let document = EPUBDocument(url: url) {
                    let title = document.title ?? url.lastPathComponent
                    let author = document.author ?? "Неизвестный автор"
                    let coverData = EpubParser.shared.extractCoverImage(at: url)
                    
                    loadedBooks.append(LocalBookIdentifiable(id: bookId, title: title, author: author, fileURL: url, coverData: coverData))
                }
            }
            DispatchQueue.main.async {
                self.localBooks = loadedBooks
            }
        } catch {
            print("Ошибка чтения папки Documents: \(error)")
        }
    }
    
    private func deleteBook(at offsets: IndexSet) {
        for index in offsets {
            let book = localBooks[index]
            try? FileManager.default.removeItem(at: book.fileURL)
            UserDefaults.standard.removeObject(forKey: "book_progress_\(book.id)")
        }
        localBooks.remove(atOffsets: offsets)
    }
} // Самая последняя закрывающая скобка структуры View
