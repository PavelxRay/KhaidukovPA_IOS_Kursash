//
//  ReaderView.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import SwiftUI

struct ReaderView: View {
    let bookTitle: String
    let chapters: [BookChapter]
    @State private var currentChapterIndex = 0
    
    var body: some View {
        VStack {
            // Постраничный вывод глав (свайп влево-вправо)
            TabView(selection: $currentChapterIndex) {
                ForEach(0..<chapters.count, id: \.self) { index in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(chapters[index].title)
                                .font(.title)
                                .bold()
                                .padding(.bottom, 10)
                            
                            Text(chapters[index].text)
                                .font(.body)
                                .lineSpacing(6)
                        }
                        .padding()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Отключаем точки снизу, делаем чистый свайп
            
            // Нижняя панель навигации по главам
            HStack {
                Button(action: { if currentChapterIndex > 0 { currentChapterIndex -= 1 } }) {
                    Image(systemName: "arrow.left.circle.fill").font(.title)
                }
                .disabled(currentChapterIndex == 0)
                
                Spacer()
                
                Text("Глава \(currentChapterIndex + 1) из \(chapters.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { if currentChapterIndex < chapters.count - 1 { currentChapterIndex += 1 } }) {
                    Image(systemName: "arrow.right.circle.fill").font(.title)
                }
                .disabled(currentChapterIndex == chapters.count - 1)
            }
            .padding()
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom))
        }
        .navigationTitle(bookTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
