//
//  ViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/6/24.
//

import UIKit
import FirebaseAuth

// TODO: Add header view ("Join a public room        120 players")
class HomeViewController: UIViewController {
    
    var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    var sections: [Section] = []
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    let settingsButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.image = UIImage(systemName: "gearshape.fill")
        return button
    }()
    
    var signInButton: UIBarButtonItem!
    var signOutButton: UIBarButtonItem!
    
    enum Section: Hashable {
        case header
        case rooms
    }
    
    enum SupplementaryViewKind {
        static let bottomLine = "bottomLine"
    }
    
    let service: FirebaseService
    
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
        
        setupLoginButton()
        setupSignOutButton()
        navigationItem.rightBarButtonItems = [settingsButton, signInButton, signOutButton]
        
        setupCollectionView()
        
        loadRooms()
    }
    
    private func setupCollectionView() {
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
        // Manages data and provides cells
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            let section = self.sections[indexPath.section]
            switch section {
            case .header:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeHeaderCollectionViewCell.reuseIdentifier, for: indexPath) as! HomeHeaderCollectionViewCell
                cell.delegate = self
                return cell
            case .rooms:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCollectionViewCell.reuseIdentifier, for: indexPath) as! RoomCollectionViewCell
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
    
    private func setupLoginButton() {
        signInButton = UIBarButtonItem(
            image: UIImage(systemName: "person.fill"),
            primaryAction: didTapSignInButton()
        )
    }
    
    private func setupSignOutButton() {
        signOutButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: didTapSignOutButton()
        )
    }
    
    private func didTapSignInButton() -> UIAction {
        return UIAction { _ in
            Task {
                if let res = await startSignInWithGoogleFlow(self) {
                    await self.service.createUser(user: res.user)
                }
            }
        }
    }
    
    private func didTapSignOutButton() -> UIAction {
        return UIAction { _ in
            do {
                try Auth.auth().signOut()
                print("Signed out")
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        }
    }
    
    private func loadRooms() {
        service.loadRooms { rooms in
            print("Got rooms: \(rooms.count)")
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.header, .rooms])
            snapshot.appendItems([.buttons], toSection: .header)
            snapshot.appendItems(rooms.map { Item.room($0.value) }, toSection: .rooms)
            self.dataSource.apply(snapshot)
        }
    }

}

extension HomeViewController: HomeHeaderCollectionViewCellDelegate {
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapCreateRoom: Bool) {
        guard let user = service.currentUser else { return }
        let createRoomViewController = CreateRoomViewController()
        createRoomViewController.service = service
        createRoomViewController.navigationItem.title = "\(user.name)'s room"
        present(UINavigationController(rootViewController: createRoomViewController), animated: true)
    }
    
    func homeHeaderCollectionViewCell(_ cell: HomeHeaderCollectionViewCell, didTapJoinRoom: Bool) {
        print(#function)
    }
    
}

#Preview {
    UINavigationController(rootViewController: HomeViewController(service: FirebaseService()))
}
