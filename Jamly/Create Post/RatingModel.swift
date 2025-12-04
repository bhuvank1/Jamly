//
//  RatingModel.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/13/25.
//

import SwiftUI
internal import Combine

class RatingModel: ObservableObject {
    @Published var rating: Int = 0
}
