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
    
    var sections: [Section] = []
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    var settingsButton: UIBarButtonItem!
    
    var activityView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.hidesWhenStopped = true
        return view
    }()
    
    let service: FirebaseService
    var roomTask: Task<Void, Never>? = nil

    enum Section: Hashable {
        case header
        case rooms
    }
    
    enum SupplementaryViewKind {
        static let bottomLine = "bottomLine"
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
        title = "🥳 Bomb Party"
        navigationController?.navigationBar.prefersLargeTitles = true
        collectionView.backgroundColor = darkBackground
        settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            primaryAction: didTapSettingsButton()
        )
        navigationItem.rightBarButtonItem = settingsButton
        
        setupCollectionView()
        loadRooms()
        
        view.addSubview(activityView)
        activityView.center = view.center
    }
    
    // class func is similar to static func but class func is overridable
    func didTapSettingsButton() -> UIAction {
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
        collectionView.register(HomeHeaderCollectionViewCell.self, forCellWithReuseIdentifier: HomeHeaderCollectionViewCell.reuseIdentifier)
        collectionView.register(RoomCollectionViewCell.self, forCellWithReuseIdentifier: RoomCollectionViewCell.reuseIdentifier)
        collectionView.register(LineView.self, forSupplementaryViewOfKind: SupplementaryViewKind.bottomLine, withReuseIdentifier: LineView.reuseIdentifier)
        
        // MARK: Collection View Setup
        collectionView.collectionViewLayout = createLayout()
        dataSource = createDataSource()
        
        sections.append(.header)
        sections.append(.rooms)
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.header, .rooms])
        snapshot.appendItems([.buttons], toSection: .header)
        dataSource.apply(snapshot)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in

            let lineItemHeight = 1 / layoutEnvironment.traitCollection.displayScale // single pixel
            let bottomLineItem = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.92),
                    heightDimension: .absolute(lineItemHeight)
                ),
                elementKind: SupplementaryViewKind.bottomLine,
                alignment: .bottom
            )

            let supplementaryItemContentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
            
            bottomLineItem.contentInsets = supplementaryItemContentInsets
            
            let section = self.sections[sectionIndex]
            switch section {
            case .header:
                let item = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(0.92),
                        heightDimension: .fractionalHeight(0.1)),
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.boundarySupplementaryItems = [bottomLineItem]
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)

                return section
            case .rooms:
                let availableLayoutWidth = layoutEnvironment.container.effectiveContentSize.width
                let groupWidth = availableLayoutWidth * 0.92
                let remainingWidth = availableLayoutWidth - groupWidth
                let halfOfRemainingWidth = remainingWidth / 2.0
                let itemLeadingAndTrailingInset = halfOfRemainingWidth
                
                let item = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: itemLeadingAndTrailingInset,
                    bottom: 0,
                    trailing: itemLeadingAndTrailingInset
                )
                
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(42)),
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
//                section.orthogonalScrollingBehavior = .groupPagingCentered

                return section
            }
        }
        
        return layout
    }
    
    private func createDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            let section = self.sections[indexPath.section]
            switch section {
            case .header:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeHeaderCollectionViewCell.reuseIdentifier, for: indexPath) as! HomeHeaderCollectionViewCell
                return cell
            case .rooms:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCollectionViewCell.reuseIdentifier, for: indexPath) as! RoomCollectionViewCell
                cell.update(room: item.room!)
                return cell
            }
        }
        
        // MARK: Supplementary View Provider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
            switch kind {
            case SupplementaryViewKind.bottomLine:
                let lineView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: LineView.reuseIdentifier, for: indexPath) as! LineView
                return lineView
            default:
                return nil
            }
        }
        
        return dataSource
    }
    
    func didSwipeToRefresh() -> UIAction {
        return UIAction { [self] _ in
            loadRooms()
        }
    }
    
    private func loadRooms() {
        roomTask?.cancel()
        roomTask = Task {
            collectionView.refreshControl?.beginRefreshing()
            let roomsDict = await service.getRooms()
            collectionView.refreshControl?.endRefreshing()
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.header, .rooms])
            snapshot.appendItems([.buttons], toSection: .header)
            snapshot.appendItems(roomsDict.map { Item.room($0.key, $0.value) }, toSection: .rooms)
            await self.dataSource.apply(snapshot)
            roomTask = nil
        }
    }
    
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let roomsSection = 1
        guard indexPath.section == roomsSection,
              let item = dataSource.itemIdentifier(for: indexPath)
        else { return }
        
        activityView.startAnimating()
        roomTask?.cancel()
        roomTask = Task {
            await joinRoom(item.roomID!)
            roomTask = nil
            activityView.stopAnimating()
        }
    }
    
    func joinRoom(_ roomID: String) async {
        guard await roomExists(roomID) else {
            showRoomDoesNotExistAlert()
            return
        }
        
        let gameViewController = GameViewController(
            gameManager: GameManager(roomID: roomID, service: service),
            chatManager: ChatManager(roomID: roomID, service: service)
        )
        
//        gameViewController.joinButton.isHidden = false
        navigationController?.pushViewController(gameViewController, animated: true)
    }
    
    private func roomExists(_ roomID: String) async -> Bool {
        let (roomSnapshot, _) = await service.ref
            .child("rooms")
            .child(roomID)
            .observeSingleEventAndPreviousSiblingKey(of: .value)
        
        return roomSnapshot.exists()
    }
    
    func showRoomDoesNotExistAlert() {
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

extension HomeViewController: HomeHeaderCollectionViewCellDelegate {
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapCreateRoom: Bool) {
        cell.createButton.isEnabled = false // to prevent button spamming
        cell.createButton.titleLabel?.isHidden = true
        cell.createActivityView.startAnimating()
        
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
            cell.createButton.isEnabled = true
            cell.createButton.titleLabel?.isHidden = false
            cell.createActivityView.stopAnimating()
            roomTask = nil
        }
    }
    
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapJoinRoom: Bool) {
        
        print(#function)
    }
    
}

#Preview {
    UINavigationController(rootViewController: HomeViewController(service: FirebaseService()))
}
