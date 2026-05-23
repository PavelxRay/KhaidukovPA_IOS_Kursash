import SwiftUI

struct BookDetailView: View {
    let book: Book
    @State private var isDownloaded = false
    @State private var isDownloading = false
    @State private var errorMessage: String? = nil
    @State private var isReadyToRead = false
    @State private var localCoverData: Data? = nil // Данные обложки из скачанного файла
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // БЛОК ДИНАМИЧЕСКОЙ ОБЛОЖКИ (Сеть -> Локальный файл)
                    Group {
                        if isDownloaded, let data = localCoverData, let uiImage = UIImage(data: data) {
                            // 1. Показываем реальную обложку из скачанного ePub-файла
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 220)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        } else if let coverURLString = book.coverURLString, let url = URL(string: coverURLString) {
                            // 2. Если книга не скачана, подгружаем превью из сети
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 220)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                case .failure, .empty:
                                    defaultCoverPlaceholder
                                @unknown default:
                                    defaultCoverPlaceholder
                                }
                            }
                        } else {
                            // 3. Резервный системный вариант
                            defaultCoverPlaceholder
                        }
                    }
                    .padding(.top, 30)
                    
                    // Блок метаданных
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(book.authorName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Современные системные кнопки управления
                    if isDownloaded {
                        Button(action: { isReadyToRead = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                Text("Читать книгу")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 30)
                    } else {
                        Button(action: {
                            Task { await downloadBook() }
                        }) {
                            HStack(spacing: 8) {
                                if isDownloading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Скачивание")
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Скачать ePub")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(book.epubURLString != nil ? Color.green : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(book.epubURLString == nil || isDownloading)
                        .padding(.horizontal, 30)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("О книге")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        // СОВРЕМЕННАЯ НАВИГАЦИЯ: Управляется через декларативный менеджер без скрытых View
        .navigationDestination(isPresented: $isReadyToRead) {
            ReaderView(
                bookTitle: book.title,
                fileURL: StorageManager.shared.getLocalFileURL(for: book.id),
                bookId: book.id
            )
        }
        .onAppear {
            checkCurrentStorageState()
        }
    }
    
    // Красивая дефолтная заглушка в стиле Apple Books
    private var defaultCoverPlaceholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 100))
            .foregroundColor(.blue.opacity(0.8))
            .frame(width: 150, height: 220)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Проверка наличия книги на диске и извлечение локальной обложки
    private func checkCurrentStorageState() {
        let downloaded = StorageManager.shared.isBookDownloaded(bookId: book.id)
        self.isDownloaded = downloaded
        
        if downloaded {
            let localURL = StorageManager.shared.getLocalFileURL(for: book.id)
            // Пытаемся вытащить обложку высокого разрешения из самого файла ePub
            if let data = EpubParser.shared.extractCoverImage(at: localURL) {
                self.localCoverData = data
            }
        }
    }
    
    private func downloadBook() async {
        guard var urlString = book.epubURLString else { return }
        if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        }
        isDownloading = true
        errorMessage = nil
        do {
            _ = try await StorageManager.shared.downloadBook(bookId: book.id, urlString: urlString)
            isDownloaded = true
            // Как только скачали — сразу парсим обложку для обновления интерфейса
            let localURL = StorageManager.shared.getLocalFileURL(for: book.id)
            self.localCoverData = EpubParser.shared.extractCoverImage(at: localURL)
        } catch {
            errorMessage = "Не удалось скачать книгу. Ошибка: \(error.localizedDescription)"
        }
        isDownloading = false
    }
}
