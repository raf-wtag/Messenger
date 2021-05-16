//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Fahim Rahman on 21/4/21.
//

import UIKit
import Firebase
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD
import SDWebImage

class ProfileViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private let spinner = JGProgressHUD(style: .dark)
    
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let username = UserDefaults.standard.value(forKey: "name") as? String ?? ""
        let userEmail = UserDefaults.standard.value(forKey: "email") as? String ?? ""
        
        data.append(ProfileViewModel(profileType: .info, title: "Name: \(username)", handler: nil))
        data.append(ProfileViewModel(profileType: .info, title: "Email: \(userEmail)", handler: nil))
        data.append(ProfileViewModel(profileType: .logout, title: "Log Out", handler: { [weak self] in
            self?.logoutButtonPressed()
        }))
        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        spinner.show(in: view)
        configureTableHeader()
    }
    
    func configureTableHeader() {
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("Error Retriving Email in createTableHeader() within ProfileViewController")
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/" + fileName
        print(path)
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .blue
        let imageView = UIImageView(frame: CGRect(x: (headerView.width-150)/2, y: 75, width: 150, height: 150))
        imageView.contentMode = .scaleToFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):
                self?.downloadImage(imageView: imageView, url: url)
                DispatchQueue.main.async {
                    self?.spinner.dismiss()
                }
                
            case .failure(let error):
                print("Failed to get download url: \(error)")
                // TODO: FIx
                let alert = UIAlertController(title: "Error", message: "Error In Fetching Profile Image", preferredStyle: .alert)
                let alertButton = UIAlertAction(title: "Okay", style: .default, handler: {_ in
                    DispatchQueue.main.async {
                        self?.spinner.dismiss()
                    }
                })
                alert.addAction(alertButton)
                self?.present(alert, animated: true)
            }
        })
        return headerView
    }
    
    func downloadImage(imageView: UIImageView, url: URL) {
        imageView.sd_setImage(with: url, completed: nil)
//        URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, response, error in
//            guard let data = data, error == nil else {
//                print("Failed DataTask in downloadImage() within ProfileViewController")
//                return
//            }
//            DispatchQueue.main.async {
//                let image = UIImage(data: data)
//                imageView.image = image
//                self?.spinner.dismiss()
//            }
//        }).resume()
    }
    
    private func logoutButtonPressed() {
        let actionSheet = UIAlertController(title: "Confirm",
                                            message: "Are you Sure you want to Logout?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            UserDefaults.standard.removeObject(forKey: "email")
            UserDefaults.standard.removeObject(forKey: "name")

            FBSDKLoginKit.LoginManager().logOut()
            
            GIDSignIn.sharedInstance()?.signOut()
            
            do {
                try Auth.auth().signOut()
                
                let vc = LoginViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                strongSelf.present(nav, animated: false)
                
            } catch {
                print("failed to Log Out")
            }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        
        present(actionSheet, animated: true)
    }
    
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
//        cell.textLabel?.text = data[indexPath.row]
//        cell.textLabel?.textAlignment = .center
//        cell.textLabel?.textColor = .red
        cell.setTableviewCellUp(with: data[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }

}

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let profileType: ProfileViewModelType
    let title: String
    let handler: (() -> ())?
}

