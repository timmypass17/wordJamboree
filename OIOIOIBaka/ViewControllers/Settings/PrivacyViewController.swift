//
//  PrivacyViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/11/24.
//

import UIKit

class PrivacyViewController: UIViewController {
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PrivacyCell")
        navigationItem.title = "Privacy Policy"
        navigationItem.largeTitleDisplayMode = .never
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension PrivacyViewController: UITableViewDataSource {
    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PrivacyCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = "Word Jamboree uses Firebase to securely store your nickname, profile picture, and in-game chat messages to enhance your gaming experience. Your nickname and profile picture are displayed to other players in-game for identification during matches, creating a social and engaging atmosphere. To keep interactions relevant, only the most recent chat message from each room is stored temporarily, with older messages automatically replaced and not retained in our database.  All data is handled with strict confidentiality and is never shared with third parties. You may delete your account at any time to permanently remove all associated data, including your nickname, profile picture, and chat messages. If you have any questions regarding this privacy policy, you can email timmysappstuff@gmail.com."
        cell.contentConfiguration = config
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Data Privacy"
    }
}
