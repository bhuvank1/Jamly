//
//  SplashScreenViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/13/25.
//

import UIKit
import FirebaseAuth
import SwiftUI

class SplashScreenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let splashView = SplashScreen {
            self.navigateNext()
        }
        
        let hostingController = UIHostingController(rootView: splashView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
    }
    
    private func navigateNext() {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let nextVC: UIViewController
            
            // user is logged in
            if Auth.auth().currentUser != nil {
                nextVC = storyboard.instantiateViewController(identifier: "mainTabVC")
            } else {
                nextVC = storyboard.instantiateViewController(identifier: "LoginVC")
            }
            
            // replace rootViewController
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                window.rootViewController = nextVC
                UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil)
            }
        }
    
}
