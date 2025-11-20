//
//  AboutPageViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/6/25.
//

import UIKit

class AboutPageViewController: UIViewController {

    @IBOutlet weak var versionTextView: UITextView!
    @IBOutlet weak var aboutTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "About Jamly"
        view.backgroundColor = UIColor(hex: "#FFEFE5")
        aboutTextView.backgroundColor = UIColor(hex: "#FFEFE5")
        versionTextView.backgroundColor = UIColor(hex: "#FFEFE5")
        
        if let font = UIFont(name: "Poppins-Regular", size: 14) {
            aboutTextView.font = font
            versionTextView.font = font
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
