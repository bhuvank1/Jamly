//
//  Track.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import Foundation
import UIKit

//Decodable allows you to automatically convert JSON data into this struct
struct Track {
    let id: String
    let name: String
    let artists: String
    let duration_ms: Int
    let albumArt: String?
    var image: UIImage?
}

struct SearchResponse {
    let tracks: [Track]
}

func mmss(from ms: Int) -> String {
    let m = ms / 60000
    let s = (ms % 60000) / 1000
    return String(format: "%d:%02d", m, s)
}
