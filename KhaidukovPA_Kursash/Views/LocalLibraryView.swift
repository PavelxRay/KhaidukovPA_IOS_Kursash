import SwiftUI
import EPUBKit

struct LocalBookIdentifiable: Identifiable {
    let id: Int
    let title: String
    let author: String
    let fileURL: URL
    let coverData: Data?
}

enum LibraryFilter {
    case all
    case reading
    case completed
}

struct LocalLibraryView: View {
    @State private var localBooks: [LocalBookIdentifiable] = []
    @State private var currentFilter: LibraryFilter = .all
    
    // Вычисляемые свойства для статистики
    private var totalBooksCount: Int {
        localBooks.count
    }
    
    private var completedBooksCount: Int {
        localBooks.filter { getProgressPercentage(for: $0) >= 100 }.count
    }
    
    private var currentlyReadingCount: Int {
        localBooks.filter {
            let percent = getProgressPercentage(for: $0)
            return percent > 0 && percent < 100
        }.count
    }
    
    private var filteredBooks: [LocalBookIdentifiable] {
        switch currentFilter {
        case .all:
            return localBooks
        case .reading:
            return localBooks.filter {
                let percent = getProgressPercentage(for: $0)
                return percent > 0 && percent < 100
            }
        case .completed:
            return localBooks.filter { getProgressPercentage(for: $0) >= 100 }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
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
                } else {
                    List {
                        // КРУПНЫЙ СТАТИЧНЫЙ ЗАГОЛОВОК (В точности как слово "Каталог")
                        Text("Библиотека")
                            .font(.system(size: 34, weight: .bold))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.top, 10)
                            .padding(.bottom, 5)
                        
                        if filteredBooks.isEmpty {
                            Text("Нет книг в этой категории")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredBooks) { book in
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
                                            Text(book.title)
                                                .font(.headline)
                                                .lineLimit(2)
                                            Text(book.author)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            let progressPercent = getProgressPercentage(for: book)
                                            VStack(alignment: .leading, spacing: 2) {
                                                ProgressView(value: progressPercent / 100.0)
                                                    .progressViewStyle(LinearProgressViewStyle(tint: progressPercent >= 100 ? .green : .blue))
                                                Text(progressPercent >= 100 ? "Прочитано" : "Прочитано: \(Int(progressPercent))%")
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
                    }
                    .listStyle(.plain)
                }
            }
            // ОТКЛЮЧАЕМ СИСТЕМНЫЙ БАР (Чтобы убрать прыжки и появление "из воздуха")
            .toolbar(.hidden, for: .navigationBar)
            
            // Фильтры-табы закреплены под строкой статуса
            .safeAreaInset(edge: .top) {
                if !localBooks.isEmpty {
                    HStack(spacing: 0) {
                        segmentedTab(title: "Все", count: totalBooksCount, isSelected: currentFilter == .all) {
                            withAnimation(.easeInOut(duration: 0.2)) { currentFilter = .all }
                        }
                        segmentedTab(title: "Читаю", count: currentlyReadingCount, isSelected: currentFilter == .reading) {
                            withAnimation(.easeInOut(duration: 0.2)) { currentFilter = .reading }
                        }
                        segmentedTab(title: "Прочитано", count: completedBooksCount, isSelected: currentFilter == .completed) {
                            withAnimation(.easeInOut(duration: 0.2)) { currentFilter = .completed }
                        }
                    }
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(9)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                    .overlay(Divider(), alignment: .bottom)
                }
            }
            .onAppear {
                reloadLocalBooks()
            }
        }
    }
    
    @ViewBuilder
    private func segmentedTab(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                Text("\(count)")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.blue : Color(.secondarySystemFill))
                    .foregroundColor(isSelected ? .white : .primary)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color(.systemBackground) : Color.clear)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
    
    private func getProgressPercentage(for book: LocalBookIdentifiable) -> Double {
        let savedPage = StorageManager.shared.getProgress(bookId: book.id)
        let totalPages = UserDefaults.standard.integer(forKey: "book_total_pages_\(book.id)")
        guard totalPages > 0 else { return 0.0 }
        let progress = (Double(savedPage + 1) / Double(totalPages)) * 100.0
        return min(max(progress, 0.0), 100.0)
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func reloadLocalBooks() {
           do {
               let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
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
               let book = filteredBooks[index]
               if let realIndex = localBooks.firstIndex(where: { $0.id == book.id }) {
                   let bookToRemove = localBooks[realIndex]
                   try? FileManager.default.removeItem(at: bookToRemove.fileURL)
                   UserDefaults.standard.removeObject(forKey: "book_progress_\(bookToRemove.id)")
                   UserDefaults.standard.removeObject(forKey: "book_total_pages_\(bookToRemove.id)")
                   localBooks.remove(at: realIndex)
               }
           }
       }
   } // Эта фигурная скобка закрывает структуру LocalLibraryView

   // Расширение идет отдельно на верхнем уровне файла
   extension Color {
       static let adaptiveBackground = Color(UIColor { traitCollection in
           return traitCollection.userInterfaceStyle == .dark ? .tertiarySystemBackground : .systemBackground
       })
   }
