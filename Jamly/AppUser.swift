//
//  AppUser.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/10/25.
//

import FirebaseFirestore

struct AppUser {
    let uid: String
    let displayName: String
    let email: String

    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]
        self.uid = doc.documentID
        self.displayName = (data["displayName"] as? String)
            ?? (data["name"] as? String)
            ?? "Unknown"
        self.email = (data["email"] as? String) ?? ""
    }
}
