//
//  SelectSongViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import UIKit

protocol SelectSongDelegate: AnyObject {
    func didSelectSong(_ track: Track)
}

class SelectSongViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {

    @IBOutlet weak var selectSongTable: UITableView!
    
    weak var delegate: SelectSongDelegate?
    
    private var results: [Track] = []
    private let searchController = UISearchController(searchResultsController: nil)
    private var pendingWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Song"
        
        selectSongTable.dataSource = self
        selectSongTable.delegate = self
        

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false  // important when no nav bar

        // Put the search bar in the table header
        let sb = searchController.searchBar
        sb.searchBarStyle = .minimal
        sb.placeholder = "Search songs or artists"
        sb.sizeToFit()
        
        selectSongTable.tableHeaderView = sb

        definesPresentationContext = true
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        // Wait for 2 chars to search
        let text = searchController.searchBar.text ?? ""
        guard text.count >= 2 else {
            pendingWorkItem?.cancel()
            results = []
            selectSongTable.reloadData()
            return
        }
        
        // Simple delay wait 250ms
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            SpotifySearchApi.shared.searchTracks(query: text, limit: 15) { result in
                switch result {
                case .success(let tracks):
                    DispatchQueue.main.async {
                        self.results = tracks
                        self.selectSongTable.reloadData()
                    }
                case .failure:
                    DispatchQueue.main.async {
                        self.results = []
                        self.selectSongTable.reloadData()
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
        cell.selectionStyle = .none
        
        
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

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let track = results[indexPath.row]
        delegate?.didSelectSong(track)    //set the delegate and then get rid of VC
        
        
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    private func mmss(from milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}

