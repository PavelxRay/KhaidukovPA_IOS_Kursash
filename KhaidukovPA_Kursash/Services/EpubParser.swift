//
//  EpubParser.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import Foundation
import EPUBKit // Импортируем нашу библиотеку

struct EpubChapter: Identifiable {
    let id = UUID()
    let title: String
    let content: String // Храним готовый чистый текст вместо капризных файлов URL
}

class EpubParser {
    static let shared = EpubParser()
    private init() {}
    
    func parseEpubFile(at url: URL) -> [EpubChapter] {
        var parsedChapters: [EpubChapter] = []
        
        // Инициализируем документ библиотеки
        guard let document = EPUBDocument(url: url) else {
            print("Ошибка: Не удалось прочитать ePub структуру документа.")
            return []
        }
        
        // 1. Запускаем рекурсивный обход оглавления по правильному свойству .subTable
        if let rootTocItems = document.tableOfContents.subTable {
            extractChaptersRecursively(from: rootTocItems, document: document, result: &parsedChapters)
        }
        
        // 2. Страховочный линейный вариант (Spine), если оглавление не дало результатов
        if parsedChapters.isEmpty {
            var index = 1
            for spineItem in document.spine.items {
                if let manifestItem = document.manifest.items[spineItem.idref] {
                    let chapterURL = document.contentDirectory.appendingPathComponent(manifestItem.path)
                    if let rawHtml = try? String(contentsOf: chapterURL, encoding: .utf8) {
                        let cleanText = cleanHTML(rawHtml, chapterTitle: "Глава \(index)")
                        parsedChapters.append(EpubChapter(title: "Глава \(index)", content: cleanText))
                        index += 1
                    }
                }
            }
        }
        
        return parsedChapters
    }
    
    // ПОЛНОСТЬЮ ИСПРАВЛЕННАЯ РЕКУРСИЯ под типы данных EPUBKit
    private func extractChaptersRecursively(from items: [EPUBTableOfContents], document: EPUBDocument, result: inout [EpubChapter]) {
        for item in items {
            if let path = item.item {
                let chapterURL = document.contentDirectory.appendingPathComponent(path)
                
                if let rawHtml = try? String(contentsOf: chapterURL, encoding: .utf8) {
                    // Передаем заголовок главы (item.label) для очистки дубликатов из текста
                    let cleanText = cleanHTML(rawHtml, chapterTitle: item.label)
                    
                    // 1. ИГНОРИРУЕМ ТЕХНИЧЕСКИЙ МУСОР: Если в тексте содержатся маркеры лицензии Гутенберга,
                    // или текст слишком короткий/вводный — не добавляем эту главу в ридер
                    let isTrash = cleanText.contains("Project Gutenberg") && (cleanText.contains("License") || cleanText.contains("EBook"))
                    let isShortIntro = cleanText.count < 150 && (item.label.lowercased().contains("title") || item.label.lowercased().contains("cover"))
                    
                    if !cleanText.isEmpty && !isTrash && !isShortIntro && !result.contains(where: { $0.title == item.label }) {
                        result.append(EpubChapter(title: item.label, content: cleanText))
                    }
                }
            }
            
            if let subChapters = item.subTable, !subChapters.isEmpty {
                extractChaptersRecursively(from: subChapters, document: document, result: &result)
            }
        }
    }
    
    private func cleanHTML(_ html: String, chapterTitle: String) -> String {
        var clean = html.replacingOccurrences(of: "<style>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "<script>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        
        clean = clean.replacingOccurrences(of: "</p>", with: "\n\n")
        clean = clean.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        clean = clean.replacingOccurrences(of: "&nbsp;", with: " ")
        clean = clean.replacingOccurrences(of: "&amp;", with: "&")
        clean = clean.replacingOccurrences(of: "&quot;", with: "\"")
        clean = clean.replacingOccurrences(of: "&#39;", with: "'")
        
        var lines = clean.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // 2. УДАЛЯЕМ ДУБЛИКА ТЕКСТА: Если первые строчки главы дублируют её название (например, "CHAPTER I")
        // или название книги ("Adventures of Huckleberry Finn"), мы их просто отрезаем
        while !lines.isEmpty {
            let firstLine = lines[0].lowercased()
            let titleLower = chapterTitle.lowercased()
            
            if firstLine == titleLower ||
               firstLine.contains("project gutenberg") ||
               firstLine.contains("adventures of") ||
               titleLower.contains(firstLine) ||
               firstLine.hasPrefix("chapter") && firstLine.count < 15 {
                lines.removeFirst() // Удаляем дублирующую строчку сверху
            } else {
                break // Как только пошел реальный текст — останавливаем чистку
            }
        }
        
        return lines.joined(separator: "\n\n")
    }

}
