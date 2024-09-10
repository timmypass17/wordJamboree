//
//  CreateRoomViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/8/24.
//

import UIKit

class CreateRoomViewController: UIViewController, UITableViewDelegate {
    
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    enum Section: Int, CaseIterable {
        case title
    }
    
//    let sections: [Section] = [.title]
    
    var cancelButton: UIBarButtonItem!
    var createButton: UIBarButtonItem!
    
    var service: FirebaseService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
//        tableView.delegate = self
        tableView.register(RoomTitleTableViewCell.self, forCellReuseIdentifier: RoomTitleTableViewCell.reuseIdentifier)
        
        cancelButton = UIBarButtonItem(systemItem: .cancel, primaryAction: didTapCancelButton())
        createButton = UIBarButtonItem(title: "Create", primaryAction: didTapCreateButton())
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = createButton
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func didTapCancelButton() -> UIAction {
        return UIAction { _ in
            self.dismiss(animated: true)
        }
    }
    
    func didTapCreateButton() -> UIAction {
        return UIAction { _ in
            // Create Room document in Firebase
            Task {
                await self.service?.createRoom(title: "timmy's room")
            }
            self.dismiss(animated: true)
        }
    }
}

extension CreateRoomViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        switch section {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: RoomTitleTableViewCell.reuseIdentifier, for: indexPath) as! RoomTitleTableViewCell
            return cell
        }
    }
    
    
}

#Preview("CreateRoomViewController") {
    UINavigationController(rootViewController: CreateRoomViewController())
}
