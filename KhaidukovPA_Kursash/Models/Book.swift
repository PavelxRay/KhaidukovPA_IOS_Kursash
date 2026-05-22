//
//  Book.swift
//  KhaidukovPA_Kursash
//
//  Created by user271126 on 5/22/26.
//

import Foundation

struct GutendexResponse: Codable {
    let results: [Book]
}

struct Book: Codable, Identifiable {
    let id: Int
    let title: String
    let authors: [Author]
    let formats: [String: String]
    
    var authorName: String {
        authors.first?.name ?? "Неизвестный автор"
    }
    
    var epubURLString: String? {
        formats["application/epub+zip"]
    }
    
    var coverURLString: String? {
        formats["image/jpeg"]
    }
}

struct Author: Codable {
    let name: String
}
