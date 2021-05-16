//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by Fahim Rahman on 21/4/21.
//

import UIKit
import JGProgressHUD

class SearchUserViewController: UIViewController {
    
    public var completion : ((SearchResult) -> ())?
    private let spinner = JGProgressHUD(style: .dark)
    private var users = [[String: String]]()
    private var hasFetched = false
    private var results = [SearchResult]()
    
    private var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search User"
        
        return searchBar
    }()
    
    private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(SearchUserTableViewCell.self, forCellReuseIdentifier: SearchUserTableViewCell.identifier)
        
        return tableView
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "No User Found"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 21, weight: .medium)
        
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        
        searchBar.delegate = self
        
        tableView.delegate = self
        tableView.dataSource = self
        
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissThisVC))
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width / 4,
                                      y: (view.height - 200) / 2,
                                      width: view.width / 2,
                                      height: 200)
    }
    
    @objc private func dismissThisVC() {
        dismiss(animated: true, completion: nil)
    }

}

extension SearchUserViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        spinner.show(in: view)
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        if hasFetched {
            filterUsers(with: query)
        } else {
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to get users with \(error)")
                }
            })
        }
    }
    
    func filterUsers(with term: String) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        self.spinner.dismiss()
        
        let results: [SearchResult] = self.users.filter( {
            guard let email = $0["email"], email != safeEmail else {
                return false
            }
            
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"], let name = $0["name"] else {
                return nil
            }
            return SearchResult(name: name, email: email)
        })
        self.results = results
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            self.noResultsLabel.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noResultsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}

extension SearchUserViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchUserTableViewCell.identifier, for: indexPath) as! SearchUserTableViewCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetUserdata = results[indexPath.row]
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUserdata)
        })
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
}
