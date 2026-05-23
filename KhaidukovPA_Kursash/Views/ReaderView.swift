import SwiftUI

struct ReaderView: View {
    let bookTitle: String
    let fileURL: URL
    let bookId: Int
    
    @State private var chapters: [EpubChapter] = []
    @State private var currentPageIndex: Int = 0
    @State private var isBookFinished = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if chapters.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка страниц")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Верхний строгий индикатор текущей главы
                Text(chapters[currentPageIndex].title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .lineLimit(1)
                
                // СОВРЕМЕННЫЙ ДИЗАЙН: Листание страниц свайпами, как в Apple Books
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<chapters.count, id: \.self) { index in
                        ScrollView {
                            Text(chapters[index].content)
                                .font(.body)
                                .lineSpacing(6)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // Отключаем стандартные точки внизу
                .onChange(of: currentPageIndex) { oldValue, newIndex in // <-- Добавили oldValue
                                    StorageManager.shared.saveProgress(bookId: bookId, currentPage: newIndex)
                                    if newIndex == chapters.count - 1 {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isBookFinished = true
                                        }
                                    }
                                }
                
                Divider()
                
                // Нижний строгий системный счетчик страниц
                Text("Страница \(currentPageIndex + 1) из \(chapters.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            // Современный фоновый контекст Task вместо DispatchQueue
            Task(priority: .userInitiated) {
                let parsed = EpubParser.shared.parseEpubFile(at: fileURL)
                await MainActor.run {
                    self.chapters = parsed
                    UserDefaults.standard.set(parsed.count, forKey: "book_total_pages_\(bookId)")
                    
                    let savedPage = StorageManager.shared.getProgress(bookId: bookId)
                    if savedPage < parsed.count {
                        self.currentPageIndex = savedPage
                    }
                }
            }
        }
        // СОВРЕМЕННЫЙ ПОП-АП: Без использования устаревшего конструктора Alert
        .alert("Книга прочитана", isPresented: $isBookFinished) {
            Button("Отлично", role: .cancel) {
                StorageManager.shared.saveProgress(bookId: bookId, currentPage: currentPageIndex)
                dismiss()
            }
        } message: {
            Text("Вы успешно завершили чтение произведения: \(bookTitle).")
        }
    }
}
