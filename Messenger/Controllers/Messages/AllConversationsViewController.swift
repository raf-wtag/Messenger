//
//  ViewController.swift
//  Messenger
//
//  Created by Fahim Rahman on 21/4/21.
//

import UIKit
import Firebase
import JGProgressHUD

class AllConversationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()

    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(AllConversationsTableViewCell.self, forCellReuseIdentifier: AllConversationsTableViewCell.identifier)
        
        return table
    }()
    
//    @IBOutlet weak var noConversationLabel: UILabel!
    private let noConversationLabel : UILabel = {
        let label = UILabel()
        label.text = "Start a Conversation"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 21, weight: .medium)
        
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButtion))
        
        setuptableView()
        
        view.addSubview(tableView)
        view.addSubview(noConversationLabel)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        noConversationLabel.isHidden = true
        spinner.show(in: view)
        checkIfAuthenticatedUser()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
    }
    
    @objc private func didTapComposeButtion() {
        let vc = SearchUserViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            
            let currentConversations = strongSelf.conversations
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == Utility.safeEmail(email: result.email)
            }) {
                let vc = ConversationViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
                self?.createNewConversation(conversation: result)
            }
            
        }
        
        
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }

    private func setuptableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isHidden = false
    }
        
    func createNewConversation(conversation: SearchResult) {
        let name = conversation.name
        let email = conversation.email
        
        DatabaseManager.shared.conversationExists(with: email, completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            
            switch result {
            
            case .success(let conversationId):
                let vc = ConversationViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            
            case .failure(_):
                let vc = ConversationViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    
    private func startListeningForConversations() {
        
        print("Check if any conversation present or not")
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("Can not retrive email from user defaults startListeningForConversations()")
            return
        }
        print("Starting Conversation fetch")
        let safeEmail = Utility.safeEmail(email: email)
        
        DatabaseManager.shared.getAllConversation(for:safeEmail, completion: { [weak self] result in
            switch result {
            case .success(let conversations):
                print("Successfullly Got conversations")
                
                guard !conversations.isEmpty else {
                    self?.tableView.isHidden = true
                    self?.noConversationLabel.isHidden = false
                    self?.spinner.dismiss()
                    return
                }
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableView.isHidden = false
                    self?.tableView.reloadData()
                    self?.spinner.dismiss()
                }
                
            case .failure(let error):
                print("Failed to Retrive conversation with - ", error)
                self?.tableView.isHidden = true
                self?.noConversationLabel.isHidden = false
                self?.spinner.dismiss()
            }
        })
    }
    
    private func checkIfAuthenticatedUser() {
        guard let availableUser = Auth.auth().currentUser else {
            print("Not Logged In")
            spinner.dismiss()
            let vc = UserLoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
            return
        }
        let loggedInUsersEmail = availableUser.email! as String
        print("Logged in user Email: ", loggedInUsersEmail)
//        UserDefaults.standard.set(loggedInUsersEmail, forKey: "email")
        startListeningForConversations()
        
//        if Auth.auth().currentUser == nil {
//            print("Not Logged In")
//            let vc = LoginViewController()
//            let nav = UINavigationController(rootViewController: vc)
//            nav.modalPresentationStyle = .fullScreen
//            present(nav, animated: false)
//        } else {
//            print("Logged In User \(Auth.auth().currentUser)")
//            startListeningForConversations()
//        }
    }

}

extension AllConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: AllConversationsTableViewCell.identifier, for: indexPath) as? AllConversationsTableViewCell
        
        cell?.configure(with: model)
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = conversations[indexPath.row]
        
        openConversation(with: model)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            DatabaseManager.shared.deleteConversation(withConversationId: conversationId, completion: { success in
                if success {
                    tableView.reloadData()
                } else {
                    print("Someting went wrong in deleting")
                }
            })
            tableView.endUpdates()
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func openConversation(with model: Conversation) {
        let vc = ConversationViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

