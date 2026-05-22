//
//  BookDetailView.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//
import SwiftUI

struct BookDetailView: View {
    let book: Book
    
    @State private var isDownloaded = false
    @State private var isDownloading = false
    @State private var errorMessage: String? = nil
    @State private var isReadyToRead = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if isDownloaded {
                    Button(action: {
                        isReadyToRead = true
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
                
                // Передаем точный URL-путь к файлу в нашей папке Documents
                NavigationLink(
                    destination: ReaderView(bookTitle: book.title, fileURL: StorageManager.shared.getLocalFileURL(for: book.id)),
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
            isDownloaded = StorageManager.shared.isBookDownloaded(bookId: book.id)
        }
    }
    
    private func downloadBook() async {
        guard var urlString = book.epubURLString else { return }
        
        // Хитрый трюк: если ссылка начинается с http://, меняем её на защищённую https://
        if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        }
        
        isDownloading = true
        errorMessage = nil
        
        do {
            _ = try await StorageManager.shared.downloadBook(bookId: book.id, urlString: urlString)
            isDownloaded = true
        } catch {
            errorMessage = "Не удалось скачать книгу. Ошибка: \(error.localizedDescription)"
        }
        isDownloading = false
    }

}
