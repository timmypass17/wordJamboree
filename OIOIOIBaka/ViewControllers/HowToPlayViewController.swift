//
//  HowToPlayViewController.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 11/5/24.
//

import UIKit

class HowToPlayViewController: UIViewController {
        
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    let gotItView: GotItView = {
        let view = GotItView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 100)
        ])
        return view
    }()

    let instructions: [Instruction] = [
        Instruction(
            title: "Objective of the Game",
            description: """
                Stay in the game by submitting a word that includes the current letter sequence! If you can't think of a valid word on your turn, you'll lose a life. The game continues until only one player remains – the last player standing wins!

                Example:
                Current Letters: "ER"
                Possible Answers: "FLOWER", "PERSON"
                """,
            image: UIImage(systemName: "trophy")!
                .withTintColor(.systemYellow, renderingMode: .alwaysOriginal)),
        Instruction(
            title: "No Repeated Words",
            description: "You can’t reuse words that have already been used.",
            image: UIImage(systemName: "exclamationmark.triangle")!
                .applyingSymbolConfiguration(.init(paletteColors: [.label, .systemOrange]))!),
        Instruction(
            title: "Losing a Life",
            description: "If the timer runs out before you submit a word, you lose a life. Players start with 3 lives.",
            image: UIImage(systemName: "heart.slash")!
                .applyingSymbolConfiguration(.init(paletteColors: [.label, .systemRed]))!),
        Instruction(
            title: "Gaining a Life",
            description: "Earn an extra life by using all the letters displayed on your keyboard throughout your turn. Players can have up to a maximum of 5 lives.",
            image: UIImage(systemName: "heart")!
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)),
        Instruction(
            title: "Timer Speed-Up",
            description: "As the game progresses, the timer may get shorter, making each turn more challenging.",
            image: UIImage(systemName: "hourglass")!
                .applyingSymbolConfiguration(.init(hierarchicalColor: .label))!),
        Instruction(
            title: "Turn Ending Sound Cues",
            description: "A ticking sound is played when your turn is nearly over! Make sure your volume is up and Silent Mode is off.",
            image: UIImage(systemName: "speaker.wave.2")!
                .applyingSymbolConfiguration(.init(paletteColors: [.systemBlue, .label]))!)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "How to Play"
        tableView.dataSource = self
        view.backgroundColor = .systemBackground
        tableView.register(InstructionTableViewCell.self, forCellReuseIdentifier: InstructionTableViewCell.reuseIdentifier)

        gotItView.doneButton.addAction(didTapExitButton(), for: .touchUpInside)

        let exitImage = UIImage(systemName: "xmark.circle.fill")!
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(hierarchicalColor: .label))
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: exitImage, primaryAction: didTapExitButton())
        
        view.addSubview(tableView)
        view.addSubview(gotItView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: gotItView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            gotItView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gotItView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gotItView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func didTapExitButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true)
        }
    }

}

extension HowToPlayViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return instructions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: InstructionTableViewCell.reuseIdentifier, for: indexPath) as! InstructionTableViewCell
        let instruction = instructions[indexPath.row]
        cell.update(title: instruction.title, description: instruction.description, image: instruction.image)
        return cell
    }
}

extension HowToPlayViewController {
    struct Instruction {
        var title: String
        var description: String
        var image: UIImage
    }
}
