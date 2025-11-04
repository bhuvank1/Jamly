//
//  PostDetailViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/3/25.
//

import UIKit

class PostDetailViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    var contentView: UIContentView!
    var postImageView: UIImageView!
    
    var post: Post?
    var captionLabel: UILabel!
    var ratingLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    

}
