//
//  SearchSongViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import UIKit

class SearchSongViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {

    @IBOutlet weak var songTableView: UITableView!
    
    private var results: [Track] = []
    private let searchController = UISearchController(searchResultsController: nil)
    private var pendingWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Song"
        
        songTableView.dataSource = self
        songTableView.delegate = self
        

        songTableView.dataSource = self
        songTableView.delegate = self
        

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false  // important when no nav bar

        // Put the search bar in the table header
        let sb = searchController.searchBar
        sb.searchBarStyle = .minimal
        sb.placeholder = "Search songs or artists"
        sb.sizeToFit()
        
        songTableView.tableHeaderView = sb
        
        // THEME
        let appBg = UIColor(hex: "#FFEFE5")
        let accent = UIColor(hex: "#FFC1CC")

        view.backgroundColor = appBg
        songTableView.backgroundColor = appBg
        songTableView.separatorColor = accent.withAlphaComponent(0.6)
        songTableView.tableFooterView = UIView()
        
        // Code to stop tab bar changes
        if let tabBar = tabBarController?.tabBar {
            let appear = UITabBarAppearance()
            appear.configureWithOpaqueBackground()
            appear.backgroundColor = appBg
            appear.shadowColor = accent.withAlphaComponent(0.4)

            tabBar.standardAppearance = appear
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appear
            }
            tabBar.isTranslucent = false
            tabBar.tintColor = .label
            tabBar.unselectedItemTintColor = .secondaryLabel
        }

        definesPresentationContext = true
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        // Simple delay wait 250ms
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            SpotifySearchApi.shared.searchTracks(query: text, limit: 15) { result in
                switch result {
                case .success(let tracks):
                    DispatchQueue.main.async {
                        self.results = tracks
                        self.songTableView.reloadData()
                    }
                case .failure:
                    DispatchQueue.main.async {
                        self.results = []
                        self.songTableView.reloadData()
                    }
                }
            }
        }
        pendingWorkItem = work //sets up delay so it isnt constantly making calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    //Table setup
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let content = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath)
        
        //font setup
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)

        cell.textLabel?.text = content.name
        cell.detailTextLabel?.text = "\(content.artists) · \(mmss(from: content.duration_ms))"
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 1
        
        // add button
        let button = UIButton(type: .system)
        button.setTitle("+ 🍓", for: .normal)
        button.backgroundColor = .clear

        // Optional: tag the button so you know which row it belongs to
        button.tag = indexPath.row

        // Add action
//        button.addTarget(self, action: #selector(addToListenLater(_:)), for: .touchUpInside)

        // Set frame (or use Auto Layout for better layout)
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 30
        button.frame = CGRect(
            x: cell.contentView.frame.width - buttonWidth - 16,
            y: (cell.contentView.frame.height - buttonHeight) / 2,
            width: buttonWidth,
            height: buttonHeight
        )

        // Add to cell
        cell.contentView.addSubview(button)
        
        
        //image setup and check
        if let cachedImage = content.image {
            cell.imageView?.image = cachedImage
            cell.setNeedsLayout()
        } else {
            cell.imageView?.image = UIImage(systemName: "music.note") //placeholder
            
            if let urlStr = content.albumArt, let url = URL(string: urlStr) {
                        URLSession.shared.dataTask(with: url) { data, _, _ in //create network request
                            guard let data = data, let img = UIImage(data: data) else { return }

                            DispatchQueue.main.async {
                                // store the image back in the array
                                self.results[indexPath.row].image = img

                                // updating the cell for this indexPath
                                cell.imageView?.image = img
                                cell.setNeedsLayout()
                                
                            }
                        }.resume()
                    }
            
            cell.setNeedsLayout()
        }
        
        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        let selected = UIView()
        selected.backgroundColor = UIColor(hex: "#FFC1CC").withAlphaComponent(0.25)
        cell.selectedBackgroundView = selected

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let track = results[indexPath.row]
        print("(Search Song) Selected \(track.name) by \(track.artists)")
    }
    
    private func mmss(from milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}

