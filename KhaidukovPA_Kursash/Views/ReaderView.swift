import SwiftUI

struct ReaderView: View {
    let bookTitle: String
    let fileURL: URL
    let bookId: Int // Передаем ID для сохранения прогресса
    
    @State private var chapters: [EpubChapter] = []
    @State private var currentPageIndex: Int = 0
    @State private var isBookFinished = false // Флаг для pop-up
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if chapters.isEmpty {
                ProgressView("Загрузка страниц...")
            } else {
                // Заголовок текущей главы на основе нашего парсера
                Text(chapters[currentPageIndex].title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                // Отображение текста текущей страницы
                ScrollView {
                    Text(chapters[currentPageIndex].content)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Нижняя панель навигации
                HStack {
                    Button(action: {
                        if currentPageIndex > 0 {
                            currentPageIndex -= 1
                            StorageManager.shared.saveProgress(bookId: bookId, currentPage: currentPageIndex)
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                        }
                    }
                    .disabled(currentPageIndex == 0)
                    
                    Spacer()
                    
                    // Информативная подпись
                    Text("Страница \(currentPageIndex + 1) из \(chapters.count)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPageIndex < chapters.count - 1 {
                            currentPageIndex += 1
                            StorageManager.shared.saveProgress(bookId: bookId, currentPage: currentPageIndex)
                        } else {
                            // Если пользователь нажал "Вперед" на самой последней странице
                            isBookFinished = true
                        }
                    }) {
                        HStack {
                            Text(currentPageIndex == chapters.count - 1 ? "Завершить" : "Вперед")
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Асинхронно парсим книгу
            DispatchQueue.global(qos: .userInitiated).async {
                let parsed = EpubParser.shared.parseEpubFile(at: fileURL)
                DispatchQueue.main.async {
                    self.chapters = parsed
                    
                    // ДОБАВЛЯЕМ ЭТУ СТРОКУ: сохраняем точное число получившихся страниц книги
                    UserDefaults.standard.set(parsed.count, forKey: "book_total_pages_\(bookId)")
                    
                    let savedPage = StorageManager.shared.getProgress(bookId: bookId)
                    if savedPage < parsed.count {
                        self.currentPageIndex = savedPage
                    }
                }
            }
        }
        // Всплывающее окно (Pop-up) об успешном прочтении
        .alert(isPresented: $isBookFinished) {
            Alert(
                title: Text("Поздравляем! 🎉"),
                message: Text("Книга «\(bookTitle)» успешно прочтена!"),
                dismissButton: .default(Text("Отлично"), action: {
                    // Сбрасываем прогресс в 0 (или оставляем на последней странице по ТЗ)
                    StorageManager.shared.saveProgress(bookId: bookId, currentPage: currentPageIndex)
                    dismiss() // Закрываем ридер и возвращаемся в библиотеку
                })
            )
        }
    }
}
