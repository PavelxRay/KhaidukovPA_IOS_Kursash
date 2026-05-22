import SwiftUI

struct ReaderView: View {
    let bookTitle: String
    let fileURL: URL
    
    @State private var chapters: [EpubChapter] = []
    @State private var currentChapterIndex = 0
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.5)
                    Text("Импорт и декомпиляция глав EPUB...")
                        .foregroundColor(.secondary)
                }
            } else if chapters.isEmpty {
                Text("Не удалось извлечь текстовые главы.")
                    .foregroundColor(.red)
                    .padding()
            } else {
                // Идеально плавный свиток текста текущей главы
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(chapters[currentChapterIndex].title)
                            .font(.title)
                            .bold()
                            .padding(.bottom, 10)
                        
                        Text(chapters[currentChapterIndex].content)
                            .font(.body)
                            .lineSpacing(6)
                    }
                    .padding()
                }
                
                // Нижняя панель навигации по главам
                HStack {
                    Button(action: {
                        if currentChapterIndex > 0 { currentChapterIndex -= 1 }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                        }
                    }
                    .disabled(currentChapterIndex == 0)
                    
                    Spacer()
                    
                    Text("Глава \(currentChapterIndex + 1) из \(chapters.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        if currentChapterIndex < chapters.count - 1 { currentChapterIndex += 1 }
                    }) {
                        HStack {
                            Text("Вперед")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .disabled(currentChapterIndex == chapters.count - 1)
                }
                .padding()
                .background(Color(.systemBackground).shadow(radius: 1))
            }
        }
        .navigationTitle(chapters.isEmpty ? bookTitle : chapters[currentChapterIndex].title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadEpubChapters()
        }
    }
    
    private func loadEpubChapters() {
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = EpubParser.shared.parseEpubFile(at: fileURL)
            DispatchQueue.main.async {
                self.chapters = parsed
                self.isLoading = false
            }
        }
    }
}
