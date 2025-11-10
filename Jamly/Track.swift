//
//  Track.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import Foundation
import UIKit

struct Track {
    let id: String
    let name: String
    let artists: String
    let duration_ms: Int
    let albumArt: String?
    var image: UIImage?
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "artists": artists,
            "duration_ms": duration_ms,
            "albumArt": albumArt ?? ""
        ]
    }
}

struct SearchResponse {
    let tracks: [Track]
}

func mmss(from ms: Int) -> String {
    let m = ms / 60000
    let s = (ms % 60000) / 1000
    return String(format: "%d:%02d", m, s)
}
