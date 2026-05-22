//
//  ContentView.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BookListViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear
                        .onAppear {
                            Task { await viewModel.loadBooks() }
                        }
                        
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Загрузка...")
                    }
                    
                case .success(let books):
                    List(books, id: \.id) { book in
                        // Добавили переход на экран деталей
                        NavigationLink(destination: BookDetailView(book: book)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(book.authorName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    
                case .error(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(.yellow)
                        Text(message).multilineTextAlignment(.center).padding(.horizontal)
                        Button("Повторить") {
                            Task { await viewModel.loadBooks(query: viewModel.searchText) }
                        }
                    }
                }
            }
            .navigationTitle("📖 Читалка")
            // Добавили нативную поисковую строку iOS
            .searchable(text: $viewModel.searchText, prompt: "Поиск книг")
            // Отслеживаем нажатие кнопки "Поиск" на клавиатуре
            .onSubmit(of: .search) {
                Task {
                    await viewModel.loadBooks(query: viewModel.searchText)
                }
            }
            // Если строку поиска полностью очистили — возвращаем общий список
            .onChange(of: viewModel.searchText) { newValue in
                if newValue.isEmpty {
                    Task { await viewModel.loadBooks() }
                }
            }
        }
    }
}
