import Foundation
import EPUBKit

struct EpubChapter: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

class EpubParser {
    static let shared = EpubParser()
    private init() {}
    
    func parseEpubFile(at url: URL) -> [EpubChapter] {
        var parsedChapters: [EpubChapter] = []
        
        guard let document = EPUBDocument(url: url) else {
            print("Ошибка: Не удалось прочитать ePub структуру документа.")
            return []
        }
        
        let spineItems = document.spine.items
        let bookTitle = document.title ?? ""
        let parasiteLine = "\(bookTitle) | Project Gutenberg".lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Строим карту оглавления: связываем имя файла с его реальным названием из книги
        var tocMap: [String: String] = [:]
        if let rootTocItems = document.tableOfContents.subTable {
            buildTocMap(from: rootTocItems, map: &tocMap)
        }
        
        var fallbackChapterIndex = 1
        
        for (fileIndex, spineItem) in spineItems.enumerated() {
            // Безжалостно выкидываем первые 4 файла (Обложка, Лицензия, Содержание, Пролог)
            if fileIndex < 4 { continue }
            
            if let manifestItem = document.manifest.items[spineItem.idref] {
                let chapterURL = document.contentDirectory.appendingPathComponent(manifestItem.path)
                if let rawHtml = try? String(contentsOf: chapterURL, encoding: .utf8) {
                    let cleanText = cleanHTML(rawHtml, parasiteLine: parasiteLine)
                    
                    if !cleanText.isEmpty && cleanText.count > 200 {
                        // Ищем настоящее название главы по имени файла
                        let filename = URL(fileURLWithPath: manifestItem.path).lastPathComponent
                        let matchedTitle = tocMap.first(where: { $0.key.contains(filename) })?.value
                        
                        // Если официального названия нет — генерируем "Глава X"
                        let currentChapterTitle = matchedTitle ?? "Глава \(fallbackChapterIndex)"
                        if matchedTitle == nil {
                            fallbackChapterIndex += 1
                        }
                        
                        let pages = splitIntoPages(content: cleanText, maxChars: 2500)
                        
                        // Формируем постраничную подпись для главы: (стр. X из Y)
                        for (pageIndex, pageContent) in pages.enumerated() {
                            let pageSuffix = " (стр. \(pageIndex + 1) из \(pages.count))"
                            let finalTitle = currentChapterTitle + pageSuffix
                            
                            parsedChapters.append(EpubChapter(title: finalTitle, content: pageContent))
                        }
                    }
                }
            }
        }
        
        return parsedChapters
    }
    
    // Сборщик словаря названий глав из оглавления книги
    private func buildTocMap(from items: [EPUBTableOfContents], map: inout [String: String]) {
            for item in items {
                // item.label — это обычная String, извлекать через if let её не нужно
                if let path = item.item {
                    let cleanLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanLabel.lowercased().contains("project gutenberg") && !cleanLabel.lowercased().contains("gutenberg") {
                        map[path] = cleanLabel
                    }
                }
                if let subChapters = item.subTable, !subChapters.isEmpty {
                    buildTocMap(from: subChapters, map: &map)
                }
            }
        }
    
    private func splitIntoPages(content: String, maxChars: Int) -> [String] {
        let paragraphs = content.components(separatedBy: "\n\n")
        var pages: [String] = []
        var currentPage = ""
        
        for paragraph in paragraphs {
            if (currentPage.count + paragraph.count) > maxChars && !currentPage.isEmpty {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = paragraph
            } else {
                if currentPage.isEmpty {
                    currentPage = paragraph
                } else {
                    currentPage += "\n\n" + paragraph
                }
            }
        }
        
        if !currentPage.isEmpty {
            pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return pages
    }
    
    private func cleanHTML(_ html: String, parasiteLine: String) -> String {
        var clean = html.replacingOccurrences(of: "<style>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "<script>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        
        // 1. Маркируем реальные абзацы временным уникальным тегом, чтобы не потерять их
        clean = clean.replacingOccurrences(of: "</p>", with: "===PARAGRAPH_BREAK===")
        clean = clean.replacingOccurrences(of: "<br\\s*/?>", with: "===PARAGRAPH_BREAK===", options: .regularExpression)
        
        // Удаляем все остальные HTML-теги
        clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "&nbsp;", with: " ")
        clean = clean.replacingOccurrences(of: "&amp;", with: "&")
        clean = clean.replacingOccurrences(of: "&quot;", with: "\"")
        clean = clean.replacingOccurrences(of: "'", with: "'")
        
        // 2. Бьем текст на куски по нашим временным маркерам абзацев
        let rawParagraphs = clean.components(separatedBy: "===PARAGRAPH_BREAK===")
        var finalParagraphs: [String] = []
        
        for rawParagraph in rawParagraphs {
            // Убираем жесткие переносы строк внутри одного абзаца, заменяя их обычными пробелами
            let singleLineParagraph = rawParagraph
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ") // Склеиваем разорванные строчки в одну красивую длинную строку
            
            let lowerLine = singleLineParagraph.lowercased()
            
            // Фильтруем технический мусор Гутенберга
            if lowerLine.contains("project gutenberg license") ||
               lowerLine.contains("online distributed proofreading") ||
               lowerLine.contains("produced by") ||
               lowerLine.contains("gutenberg.org") {
                continue
            }
            
            if !parasiteLine.isEmpty && (lowerLine == parasiteLine || lowerLine.contains(parasiteLine)) {
                continue
            }
            
            if !singleLineParagraph.isEmpty {
                finalParagraphs.append(singleLineParagraph)
            }
        }
        
        // 3. Соединяем абзацы обратно через красивый двойной отступ
        return finalParagraphs.joined(separator: "\n\n")
    }

    
    func extractCoverImage(at url: URL) -> Data? {
        guard let document = EPUBDocument(url: url) else { return nil }
        if let coverURL = document.cover {
            return try? Data(contentsOf: coverURL)
        }
        if let coverItem = document.manifest.items.values.first(where: {
            $0.id.lowercased().contains("cover") || $0.mediaType.rawValue.lowercased().contains("image")
        }), let data = try? Data(contentsOf: document.contentDirectory.appendingPathComponent(coverItem.path)) {
            return data
        }
        return nil
    }
}
