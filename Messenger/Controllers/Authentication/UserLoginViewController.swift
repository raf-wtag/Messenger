//
//  LoginViewController.swift
//  Messenger
//
//  Created by Fahim Rahman on 21/4/21.
//

import UIKit
import Firebase
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

class UserLoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
//        field.backgroundColor = .secondarySystemBackground
        if #available(iOS 13.0, *) {
            field.backgroundColor = .secondarySystemBackground
        } else {
            field.backgroundColor = .gray
        }
        
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
//        field.backgroundColor = .secondarySystemBackground
        if #available(iOS 13.0, *) {
            field.backgroundColor = .secondarySystemBackground
        } else {
            field.backgroundColor = .gray
        }
        field.isSecureTextEntry = true
        
        return field
    }()
    
    private let loginByEmailButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
//        button.backgroundColor = .link
        if #available(iOS 13.0, *) {
            button.backgroundColor = .link
        } else {
            button.backgroundColor = .blue
        }
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        
        return button
    }()
    
    private let loginByFacebookButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        
        return button
    }()
    
    private let loginByGogoleButton = GIDSignInButton()
    
    private var googleLoginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GIDSignIn.sharedInstance()?.presentingViewController = self
        
        googleLoginObserver = NotificationCenter.default.addObserver(forName: Notification.Name("didLogInNotification"), object: nil, queue: .main, using: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })

        title = "Log In"
//        view.backgroundColor = .systemBackground
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                                                    style: .done,
                                                                                    target: self,
                                                                                    action: #selector(didTapRegister))
        
        loginByEmailButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
        loginByFacebookButton.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginByEmailButton)
        scrollView.addSubview(loginByFacebookButton)
        scrollView.addSubview(loginByGogoleButton)
    }
    
    deinit {
        if let observer = googleLoginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width-size)/2,
                                                y: 20,
                                                width: size,
                                                height: size)
        emailField.frame = CGRect(x: 30,
                                        y: imageView.bottom + 10,
                                        width: scrollView.width-60,
                                        height: 52)
        passwordField.frame = CGRect(x: 30,
                                        y: emailField.bottom + 10,
                                        width: scrollView.width-60,
                                        height: 52)
        loginByEmailButton.frame = CGRect(x: 30,
                                        y: passwordField.bottom + 10,
                                        width: scrollView.width-60,
                                        height: 52)
        loginByFacebookButton.frame = CGRect(x: 30,
                                        y: loginByEmailButton.bottom + 10,
                                        width: scrollView.width-60,
                                        height: 52)
        loginByGogoleButton.frame = CGRect(x: 30,
                                        y: loginByFacebookButton.bottom + 10,
                                        width: scrollView.width-60,
                                        height: 52)
    }
    
    @objc private func loginButtonTapped() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text, !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLoginError(for: "Plese Enter All Info")
            return
        }
        
        spinner.show(in: view)
        
        Auth.auth().signIn(withEmail: email, password: password, completion: { [weak self] authResult, error in
            guard let strongSelf = self else { return }
            
            UserDefaults.standard.set(email, forKey: "email")
            
            guard let result = authResult, error == nil else {
                print("Failed to log in with email: \(email)")
                self?.spinner.dismiss()
                self?.alertUserLoginError(for: "User is Not Registered")
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            let user = result.user
            
            let safeEmail = Utility.safeEmail(email: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result {
                
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let firstName = userData["first_name"],
                          let lastName = userData["last_name"] else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                    
                case .failure(let error):
                    print("Failed to read data with -", error)
                }
            })
            print("Logged in user \(user)")
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
    }
    
    private func alertUserLoginError(for errorMeaasge: String) {
        let alert = UIAlertController(title: "Error",
                                      message: errorMeaasge,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = UserRegistrationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

}


extension UserLoginViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}

extension UserLoginViewController: LoginButtonDelegate {
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("Failded to login using Facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields": "email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token,
                                                         version: nil,
                                                         httpMethod: .get)
        
        facebookRequest.start(completionHandler: { _, result, error in
            guard let result = result as? [String: Any], error == nil else {
                print("Failed to make Facebook graph request")
                return
            }
            
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String: Any],
                  let pictureURL = data["url"] as? String else {
                print("failed to get name and email from facebook")
                return
            }
            
            
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            UserDefaults.standard.set(email, forKey: "email")
            
            DatabaseManager.shared.userExists(with: email, completionHandler: { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstname: firstName,
                                               lastName: lastName,
                                               email: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                        if success {
                            guard let url = URL(string: pictureURL) else {
                                return
                            }
                            
                            URLSession.shared.dataTask(with: url, completionHandler: {data, _, error in
                                guard let data = data, error == nil else {
                                    return
                                }
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: { results in
                                    switch results {
                                    case .success(let downloadURL):
                                        print(downloadURL)
                                        UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
                                    case .failure(let error):
                                        print("Storage manager Error \(error)")
                                    }
                                })
                            }).resume()
                        }
                    })
                }
            })
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                guard let strongSelf = self else {
                    return
                }
                
                guard authResult != nil, error == nil else {
                    print("Facbook Credential Log in Failed MFA may be needed")
                    return
                }
                print("Successfully Logged In")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
            
        })
    }

    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // No Operation
    }


}
