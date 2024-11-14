//
//  ThemeTableViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/13/24.
//

import UIKit

protocol ThemeTableViewControllerDelegate: AnyObject {
    func themeTableViewController(_ controller: ThemeTableViewController, didSelectTheme theme: UIUserInterfaceStyle)
}

class ThemeTableViewController: UITableViewController {

    weak var delegate: ThemeTableViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ThemeCell")
        navigationItem.title = "Theme"
        navigationItem.largeTitleDisplayMode = .never
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UIUserInterfaceStyle.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCell", for: indexPath)
        let themeType = UIUserInterfaceStyle.allCases[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = themeType.description
        cell.contentConfiguration = content
        cell.accessoryType = themeType == Settings.shared.theme ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let theme = UIUserInterfaceStyle.allCases[indexPath.row]
        Settings.shared.theme = theme
        NotificationCenter.default.post(name: Settings.shared.themeChangedNotification, object: nil)
        delegate?.themeTableViewController(self, didSelectTheme: theme)
        tableView.reloadData()
    }
}
