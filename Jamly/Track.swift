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

    static func fromDictionary(_ dict: [String: Any]) -> Track? {
        guard
            let id = dict["id"] as? String,
            let name = dict["name"] as? String,
            let artists = dict["artists"] as? String,
            let duration_ms = dict["duration_ms"] as? Int
        else { return nil }

        let albumArt = (dict["albumArt"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return Track(id: id, name: name, artists: artists, duration_ms: duration_ms, albumArt: albumArt, image: nil)
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
