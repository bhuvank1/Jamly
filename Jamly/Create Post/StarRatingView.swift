//
//  StarRatingView.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/13/25.
//

import SwiftUI

struct StarRatingView: View {
    @ObservedObject var model: RatingModel
    let maximumRating = 5
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Rate Your Jam!")
                .font(.headline)
                .foregroundColor(Color("AppTextColor"))
                .padding(.top, 8)
            
        HStack(spacing: 8) {
            ForEach(1...maximumRating, id: \.self) { number in
                Image(systemName: number <= model.rating ? "star.fill" : "star")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.yellow)
                    .onTapGesture {
                        model.rating = number
                        print("Tapped star \(number)")
                    }
            }
            }
        .padding(.vertical, 8)
        }
        .frame(width: 389.0, height: 128.0)
        .background(Color("BackgroundAppColor"))
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    StarRatingView(model: RatingModel())
}
