//
//  SplashScreen.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/13/25.
//


//
//  SplashScreen.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/13/25.
//

import SwiftUI
import FirebaseAuth

struct SplashScreen: View {
    @State private var progress: Double = 0.0
    var onFinish: (() -> Void)?
    
    
    var body: some View {
        VStack(spacing: 60) {
            Image("Jamly_LogoPDF").resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
            
            ProgressView(value: min(max(progress, 0), 1))
                .progressViewStyle(LinearProgressViewStyle(tint: .black))
                .frame(height: 10)
                .padding(.horizontal, 50)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                        if progress < 1 {
                            progress += 0.01
                        } else {
                            timer.invalidate()
                            onFinish?()
                        }
                    }
                }
            
        }
        
        
    }
}
    

#Preview {
    SplashScreen()
}
