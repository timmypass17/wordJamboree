//
//  ViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit
import FirebaseAuth
import FirebaseDatabaseInternal

class HomeViewController: UIViewController {
    
    var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    var settingsButton: UIBarButtonItem!
    
    var activityView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var sections: [Section] = [.rooms]
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    let service: FirebaseService
    var roomTask: Task<Void, Never>? = nil

    enum Item: Hashable {
        case room(String, Room)
        
        var roomID: String? {
            if case .room(let roomID, _) = self {
                return roomID
            } else {
                return nil
            }
        }
        
        var room: Room? {
            if case .room(_, let room) = self {
                return room
            } else {
                return nil
            }
        }
    }
    
    enum Section: Hashable {
        case rooms
    }
    
    enum SupplementaryViewKind: String {
        case header
        case bottomLine
    }
    
    init(service: FirebaseService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "🥳 Word Jamboree"
        navigationController?.navigationBar.prefersLargeTitles = true
        collectionView.backgroundColor = .wjBackground
        settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            primaryAction: didTapSettingsButton()
        )
        navigationItem.rightBarButtonItem = settingsButton
        
        setupCollectionView()
        loadRooms()
        
        view.addSubview(activityView)
        
        NSLayoutConstraint.activate([
            activityView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // class func is similar to static func but class func is overridable
    private func didTapSettingsButton() -> UIAction {
        return UIAction { _ in
            let settingsViewController = SettingsViewController()
            settingsViewController.service = self.service
            self.navigationController?.pushViewController(settingsViewController, animated: true)
        }
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addAction(didSwipeToRefresh(), for: .valueChanged)
        
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // MARK: Register cells/supplmentary views
        collectionView.register(RoomCollectionViewCell.self, forCellWithReuseIdentifier: RoomCollectionViewCell.reuseIdentifier)
        
        collectionView.register(HomeHeaderView.self, forSupplementaryViewOfKind: SupplementaryViewKind.header.rawValue, withReuseIdentifier: HomeHeaderView.reuseIdentifier)
        collectionView.register(LineView.self, forSupplementaryViewOfKind: SupplementaryViewKind.bottomLine.rawValue, withReuseIdentifier: LineView.reuseIdentifier)
        
        // MARK: Collection View Setup
        collectionView.collectionViewLayout = createLayout()
        dataSource = createDataSource()
                
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.rooms])
        dataSource.apply(snapshot)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        // 2 Types of layouts
        // - Flow: grid layout
        // - Compositional: custom layout (sections, groups, items)
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in

            let availableLayoutWidth = layoutEnvironment.container.effectiveContentSize.width
            let groupWidth = availableLayoutWidth * 0.92
            let remainingWidth = availableLayoutWidth - groupWidth
            let halfOfRemainingWidth = remainingWidth / 2.0
            let itemLeadingAndTrailingInset = halfOfRemainingWidth

            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1), // diff, was .92
                    heightDimension: .estimated(200)
                ),
                elementKind: SupplementaryViewKind.header.rawValue,
                alignment: .top
            )
            
            headerItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)  // align with 4 extra padding

            let section = self.sections[sectionIndex]
            switch section {
            case .rooms:
                let item = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)    // horizontal spacing, 4 extra outside, 8 padding inner
                
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1/2),
                        heightDimension: .fractionalHeight(1/8)),
                    repeatingSubitem: item,
                    count: 2
                )
                
                group.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
                
                let section = NSCollectionLayoutSection(group: group)
                
                section.boundarySupplementaryItems = [headerItem]
                
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: itemLeadingAndTrailingInset, bottom: 0, trailing: itemLeadingAndTrailingInset) // affects header
                

                return section
            }
        }
        
        return layout
    }
    
    private func createDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            let section = self.sections[indexPath.section]
            switch section {
            case .rooms:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCollectionViewCell.reuseIdentifier, for: indexPath) as! RoomCollectionViewCell
                cell.update(room: item.room!)
                return cell
            }
        }
        
        // MARK: Supplementary View Provider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
            let viewKind = SupplementaryViewKind(rawValue: kind) ?? nil
            switch viewKind {
            case .header:
                let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: HomeHeaderView.reuseIdentifier, for: indexPath) as! HomeHeaderView
                headerView.delegate = self
                return headerView
            case .bottomLine:
                let lineView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: LineView.reuseIdentifier, for: indexPath) as! LineView
                return lineView
            case .none:
                return nil
            }
        }
        
        
        return dataSource
    }
    
    // Called multple time if hold?
    private func loadRooms() {
        roomTask?.cancel()
        roomTask = Task {
            collectionView.refreshControl?.beginRefreshing()
            let roomsDict = await service.getRooms()
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.rooms])
            snapshot.appendItems(roomsDict.map { Item.room($0.key, $0.value) }
                                          .sorted { $0.room!.createdAt > $1.room!.createdAt },
                                 toSection: .rooms)
            await self.dataSource.apply(snapshot, animatingDifferences: false)  // wierd to see rooms move around
            collectionView.refreshControl?.endRefreshing()
            roomTask = nil
        }
    }
    
    
    private func joinRoom(_ roomID: String) async {
        guard await service.roomExists(roomID) else {
            invalidRoomAlert()
            return
        }
        
        let gameViewController = GameViewController(
            gameManager: GameManager(roomID: roomID, service: service),
            chatManager: ChatManager(roomID: roomID, service: service)
        )
        
        navigationController?.pushViewController(gameViewController, animated: true)
    }
    
    
    private func didSwipeToRefresh() -> UIAction {
        return UIAction { [self] _ in
            loadRooms()
        }
    }
    
    private func invalidRoomAlert() {
        let alert = UIAlertController(
            title: "Room Not Found",
            message: "The room you're trying to join doesn't exist or may have been closed. Please swipe down to refresh the room list",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        self.present(alert, animated: true, completion: nil)
    }
}

extension HomeViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        activityView.startAnimating()
        
        roomTask?.cancel()
        roomTask = Task {
//            defer { // called when exiting scope, no matter what. Used for clean up
//                isJoiningRoom = false // Unlock after task finishes
//                activityView.stopAnimating()
//                roomTask = nil
//            }
            
            await joinRoom(item.roomID!)
            activityView.stopAnimating()
            roomTask = nil
        }
    }
}

extension HomeViewController: HomeHeaderViewDelegate {
    func homeHeaderView(_ sender: HomeHeaderView, didTapCreateRoom: Bool) {
        sender.createButton.isEnabled = false // to prevent button spamming
        sender.createButton.titleLabel?.isHidden = true
        sender.createActivityView.startAnimating()
        
        roomTask?.cancel()
        roomTask = Task {
            do {
                let (roomID, _) = try await service.createRoom(title: "\(service.name)'s room")
                let gameManager = GameManager(roomID: roomID, service: service)
                let gameViewController = GameViewController(gameManager: gameManager, chatManager: ChatManager(roomID: roomID, service: service))
                gameViewController.leaveButton.isHidden = false
                
                navigationController?.pushViewController(gameViewController, animated: true)
            } catch {
                print("Failed to create room: \(error)")
            }
            sender.createButton.isEnabled = true
            sender.createButton.titleLabel?.isHidden = false
            sender.createActivityView.stopAnimating()
            roomTask = nil
        }
    }
    
    func homeHeaderView(_ sender: HomeHeaderView, didTapHowToPlay: Bool) {
        let howToPlayViewController = HowToPlayViewController()
        navigationController?.present(UINavigationController(rootViewController: howToPlayViewController), animated: true)
    }
    
}
