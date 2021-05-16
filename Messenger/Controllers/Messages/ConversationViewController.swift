//
//  ChatViewController.swift
//  Messenger
//
//  Created by Fahim Rahman on 22/4/21.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit

class ConversationViewController: MessagesViewController {
    
    public static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM_dd_yyyy_h_mm_ss"
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .long
        return formatter
    }()
    
    public var isNewConversation = false
    public let  otherUserEmail:  String
    private let  conversationId:  String?

    private var messages = [Message]()
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        return Sender(photoURL: "",
               senderId: safeEmail,
               displayName: "IJK")
    }
    
    private func listenForMessages(id: String) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            print("In listenForMessages")
            switch result {
            
            case .success(let messages):
                guard !messages.isEmpty else {
                    print("In guard listenForMessages()", messages)
                    return
                }
                print(messages)
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                }
                
            case .failure(let error):
                print("Faild to get message with error", error)
            }
        })
    }
    
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        
        if let conversationId = conversationId {
            listenForMessages(id: conversationId)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .blue
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        messagesCollectionView.messageCellDelegate = self
        
        setupInputButtons()
    }
    
    private func setupInputButtons() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 30, height: 30), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({ [weak self]  _ in
            self?.presentActionSheet()
        })
        messageInputBar.setLeftStackViewWidthConstant(to: 31, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentActionSheet() {
        let actionSheet = UIAlertController(title: "Select Media",
                                            message: "Select your Media Type",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoSelectionActionSheet()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoSelectionActionSheet()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
        
    }
    
    private func presentPhotoSelectionActionSheet() {
        let actionSheet = UIAlertController(title: "Attatch Photo",
                                            message: "Select your Photo Source",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil ))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoSelectionActionSheet() {
        let actionSheet = UIAlertController(title: "Attatch Video",
                                            message: "Select your Video Source",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil ))
        
        present(actionSheet, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }

}

extension ConversationViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is Nill!!")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        switch message.kind {
        case .photo(let media):
            guard let imageURL = media.url else {
                return
            }
            imageView.sd_setImage(with: imageURL, completed: nil)
        default:
            break
        }
    }
}

extension ConversationViewController: MessageCellDelegate {
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageURL = media.url else {
                return
            }
            let vc = PhotoMessageViewController(with: imageURL)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoURL = media.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoURL)
            present(vc, animated: true)
        default:
            break
        }
    }
}

extension ConversationViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageID = createMessageId()  else {
            return
        }
        print("\(text)")
        
        let message = Message(sender: selfSender,
                              messageId: messageID,
                              sentDate: Date(),
                              kind: .text(text))
        
        if isNewConversation {
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message, completion: { success in
                if success {
                    print("Message Sent")
                    self.isNewConversation = false
                } else {
                    print("Failed to send")
                }
            })
        } else {
            guard let conversationId = conversationId, let name = self.title else {
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, name: name, otherUserEmail: otherUserEmail, newMessage: message, completion: { success in
                if success {
                    print("Message Sent")
                } else {
                    print("Failed to send")
                }
            })
        }
        inputBar.inputTextView.text = ""
    }
    
    private func createMessageId() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        
        let newID = "\(otherUserEmail)_\(safeEmail)_\(dateString)"
        print("Created Message ID - ", newID)
        
        return newID
    }
}

extension ConversationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageID = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = self.selfSender else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message" + messageID + ".png"
            // upload image
            StorageManager.shared.uploadPhotoImage(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let self = self else {
                    return
                }
                
                switch result {
                case .success(let url):
                    print("uploaded image name - ", fileName)
                    
                    guard let mediaURL = URL(string: url), let placeholder = UIImage(systemName: "stop") else {
                        return
                    }
                    
                    let mediaItem = Media(url: mediaURL,
                                          image: nil,
                                          placeholderImage: placeholder,
                                          size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageID,
                                          sentDate: Date(),
                                          kind: .photo(mediaItem))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, name: name, otherUserEmail: self.otherUserEmail, newMessage: message, completion: { success in
                        switch success {
                        
                        case true:
                            print("sent photo message")
                        case false:
                            print("failed to send photo message")
                        }
                    })
                    
                case .failure(let error):
                    print("Photo message upload error with \(error)")
                }
                
            })
        } else if let videoURL = info[.mediaURL] as? URL {
            let fileName = "video_message" + messageID + ".mov"
            
            StorageManager.shared.uploadVideoMessage(with: videoURL, fileName: fileName, completion: { [weak self] result in
                guard let self = self else {
                    return
                }
                
                switch result {
                case .success(let url):
                    print("uploaded video name - ", fileName)
                    print("uploaded video url - ", videoURL)
                    
                    guard let mediaURL = URL(string: url), let placeholder = UIImage(systemName: "stop") else {
                        return
                    }
                    
                    let mediaItem = Media(url: mediaURL,
                                          image: nil,
                                          placeholderImage: placeholder,
                                          size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageID,
                                          sentDate: Date(),
                                          kind: .video(mediaItem))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, name: name, otherUserEmail: self.otherUserEmail, newMessage: message, completion: { success in
                        switch success {
                        
                        case true:
                            print("sent photo message")
                        case false:
                            print("failed to send photo message")
                        }
                    })
                    
                case .failure(let error):
                    print("Photo message upload error with \(error)")
                }
                
            })
        }
        // send message
        
    }
}
