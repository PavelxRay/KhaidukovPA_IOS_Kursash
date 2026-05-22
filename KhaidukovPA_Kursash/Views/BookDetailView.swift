//
//  BookDetailView.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import SwiftUI

struct BookDetailView: View {
    let book: Book
    
    // Состояния для отслеживания загрузки файла
    @State private var isDownloaded = false
    @State private var isDownloading = false
    @State private var errorMessage: String? = nil
    
    // Состояние для перехода на экран чтения
    @State private var parsedChapters: [BookChapter] = []
    @State private var isReadyToRead = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Красивая обложка
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 110))
                    .foregroundColor(.blue)
                    .padding(.top, 30)
                    .shadow(radius: 5)
                
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
                
                // Вывод ошибки скачивания, если она возникнет
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Динамическая кнопка Скачать / Читать
                if isDownloaded {
                    // Кнопка открытия Читалки
                    Button(action: {
                        openBook()
                    }) {
                        HStack {
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
                    // Кнопка Скачивания
                    Button(action: {
                        Task { await downloadBook() }
                    }) {
                        HStack {
                            if isDownloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                                Text("Скачивание...")
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
                
                // Скрытая навигация для программного перехода в ридер после парсинга
                NavigationLink(
                    destination: ReaderView(bookTitle: book.title, chapters: parsedChapters),
                    isActive: $isReadyToRead
                ) {
                    EmptyView()
                }
                
                Spacer()
            }
        }
        .navigationTitle("О книге")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // При открытии экрана проверяем, скачана ли уже эта книга
            isDownloaded = StorageManager.shared.isBookDownloaded(bookId: book.id)
        }
    }
    
    // Логика асинхронного скачивания файла
    private func downloadBook() async {
        guard let urlString = book.epubURLString else { return }
        isDownloading = true
        errorMessage = nil
        
        do {
            _ = try await StorageManager.shared.downloadBook(bookId: book.id, urlString: urlString)
            isDownloaded = true
        } catch {
            errorMessage = "Не удалось скачать книгу. Попробуйте позже."
        }
        isDownloading = false
    }
    
    // Логика чтения и парсинга перед открытием экрана
    private func openBook() {
        let fileURL = StorageManager.shared.getLocalFileURL(for: book.id)
        // Запускаем твой алгоритм разбора ePub структуры
        let chapters = EpubParser.shared.parseEpub(at: fileURL)
        
        if !chapters.isEmpty {
            self.parsedChapters = chapters
            self.isReadyToRead = true
        }
    }
}
