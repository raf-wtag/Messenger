//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Fahim Rahman on 21/4/21.
//

import Foundation
import Firebase
import MessageKit

final class DatabaseManager {
    
    static let shared = DatabaseManager()
            
    private let database = Database.database().reference()
    
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }

}

extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>)->()) {
        self.database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.faildToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public func userExists(with email: String,
                           completionHandler: @escaping ((Bool) -> ())) {
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapShot in
            guard snapShot.value as? [String: Any] != nil else {
                completionHandler(false)
                return
            }
            completionHandler(true)
        })
    }
    
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> ()) {
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstname,
            "last_name" : user.lastName,
        ], withCompletionBlock: {error, _ in
            guard error == nil else {
                print("Failed to write to database")
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: {snapShot in
                if var usersCollection = snapShot.value as? [[String: String]] {
                    // Append to the dict
                    let newElement = [
                        "name" : user.firstname + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    
                } else {
                    // create dict
                    let newCollection : [[String: String]] = [
                        [
                            "name" : user.firstname + " " + user.lastName,
                            "email": user.safeEmail
                        ],
                    ]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String:String]], Error>) -> ()) {
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.faildToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case faildToFetch
    }
}

// MARK: Sending message / conversation
extension DatabaseManager {
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> ()) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentEmail)
        
        let reference = database.child("\(safeEmail)")
        reference.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User Not found..")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String : Any] = [
                "id": conversationId,
                "other_user_email" : otherUserEmail,
                "name" : name,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            ]
            
            let recipient_newConversationData: [String : Any] = [
                "id": conversationId,
                "other_user_email" : safeEmail,
                "name" : currentName,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            ]
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    self?.database.child("\(otherUserEmail)/conversations").setValue([
                        recipient_newConversationData
                    ])
                }
            })
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishedCreatingConversation(conversationID: conversationId, name:name, firstMessage: firstMessage, completion: completion)
                })
            } else {
                userNode["conversations"] = [
                    newConversationData
                ]
                
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishedCreatingConversation(conversationID: conversationId, name: name, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    private func finishedCreatingConversation(conversationID: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> ()) {
       
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        var message = ""
        
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let _email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(email: _email)
        
        let messageStruct: [String: Any] = [
            "id" : firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date" : dateString,
            "is_read" : false,
            "sender_email" : currentUserEmail,
            "name" : name
        ]
        
        let value: [String: Any] = [
            "message" : [
                messageStruct
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    public func getAllConversation(for email: String, completion: @escaping (Result<[Conversation], Error>) -> ()) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.faildToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
                
            })
            completion(.success(conversations))
        })
    }
    
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> ()) {
        database.child("\(id)/message").observe(.value, with: { snapshot in
            print("Before guard", snapshot)
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.faildToFetch))
                print("Faild Here getAllMessagesForConversation")
                return
            }
            print("Success in getAllMessagesForConversation")
            let messages: [Message] = value.compactMap({ dictionary in
               guard let name = dictionary["name"] as? String,
//                     let isRead = dictionary["is_read"] as? Bool,
                     let messageID = dictionary["id"] as? String,
                     let content = dictionary["content"] as? String,
                     let senderEmail = dictionary["sender_email"] as? String,
                     let type = dictionary["type"] as? String,
                     let dateString = dictionary["date"] as? String,
                     let date = ChatViewController.dateFormatter.date(from: dateString) else {
                print("Error in guard ...")
                return nil
               }
                
                var messageType: MessageKind?
                if type == "photo" {
                    guard let targetURL = URL(string: content),
                          let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    
                    let media = Media(url: targetURL,
                                        image: nil,
                                        placeholderImage: placeholder,
                                        size: CGSize(width: 300, height: 300))
                    
                    messageType = .photo(media)
                    
                } else if type == "video" {
                    guard let targetURL = URL(string: content),
                          let placeholder = UIImage(systemName: "stop") else {
                        return nil
                    }
                    
                    let media = Media(url: targetURL,
                                        image: nil,
                                        placeholderImage: placeholder,
                                        size: CGSize(width: 300, height: 300))
                    
                    messageType = .video(media)
                    
                } else {
                    messageType = .text(content)
                }
                
                guard let messagekind = messageType else {
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: messagekind)
            })
            print("Now messages", messages)
            completion(.success(messages))
        })
    }
    
    public func sendMessage(to conversation: String, name: String, otherUserEmail: String, newMessage: Message, completion:  @escaping (Bool) -> ()) {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(email: email)
        
        self.database.child("\(conversation)/message").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
                
            case .video(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
//            guard let _email = UserDefaults.standard.value(forKey: "email") as? String else {
//                completion(false)
//                return
//            }
//            let currentUserEmail = DatabaseManager.safeEmail(email: _email)
            
            let messageStruct: [String: Any] = [
                "id" : newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date" : dateString,
                "is_read" : false,
                "sender_email" : currentUserEmail,
                "name" : name
            ]
            
            currentMessages.append(messageStruct)
            
            strongSelf.database.child("\(conversation)/message").setValue(currentMessages, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    
                    let updatedValue: [String: Any] = [
                        "date" : dateString,
                        "is_read" : false,
                        "message" : message
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String:Any]] {
                        var targetConversation: [String:Any]?
                        var position = 0
                       
                        for conversationItem in currentUserConversations {
                            if let currentId = conversationItem["id"] as? String, currentId == conversation {
                                targetConversation = conversationItem
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String : Any] = [
                                "id": conversation,
                                "other_user_email" : DatabaseManager.safeEmail(email: otherUserEmail),
                                "name" : name,
                                "latest_message" : updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        let newConversationData: [String : Any] = [
                            "id": conversation,
                            "other_user_email" : DatabaseManager.safeEmail(email: otherUserEmail),
                            "name" : name,
                            "latest_message" : updatedValue
                        ]
                        
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    

                    strongSelf.database.child("\(currentUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            var databaseEntryConversations = [[String: Any]]()
                            
                            guard let currentUserName = UserDefaults.standard.value(forKey: "name") as? String else {
                                print("Current User name is not retrived from userdefaults")
                                return
                            }
                            let updatedValue: [String: Any] = [
                                "date" : dateString,
                                "is_read" : false,
                                "message" : message
                            ]
                            
                            if var otherUserConversations = snapshot.value as? [[String:Any]] {
                                var targetConversation: [String:Any]?
                                var position = 0
                               
                                for conversationItem in otherUserConversations {
                                    if let currentId = conversationItem["id"] as? String, currentId == conversation {
                                        targetConversation = conversationItem
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    let newConversationData: [String : Any] = [
                                        "id": conversation,
                                        "other_user_email" : DatabaseManager.safeEmail(email: currentUserEmail),
                                        "name" : currentUserName,
                                        "latest_message" : updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }

                            } else {
                                let newConversationData: [String : Any] = [
                                    "id": conversation,
                                    "other_user_email" : DatabaseManager.safeEmail(email: currentUserEmail),
                                    "name" : currentUserName,
                                    "latest_message" : updatedValue
                                ]
                                
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                        completion(true)
                    })
                })
            })
        })
    }
    
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> ()) {
        let safeRecipientEmail = DatabaseManager.safeEmail(email: targetRecipientEmail)
        
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(email: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.faildToFetch))
                return
            }
            
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                guard let fetchedId = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.faildToFetch))
                    return
                }
                completion(.success(fetchedId))
                return
            }
            completion(.failure(DatabaseError.faildToFetch))
        })
    }
    
    public func deleteConversation(withConversationId conversationId: String, completion: @escaping (Bool) -> ()) {
        guard let retrivedEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            print("Error in retrived emial from userDefaults in retrivedEmail()")
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(email: retrivedEmail)

        let databaseReference = database.child("\(currentUserEmail)/conversations")
        
        print("Deleting conversation with conversatioId -", conversationId)
        databaseReference.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        print("Found Conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                print("Position of the conversation is -", positionToRemove)
                conversations.remove(at: positionToRemove)
                databaseReference.setValue(conversations, withCompletionBlock: { error, ref in
                    guard error == nil else {
                        print("Error in resave the conversation in deleteConversation()")
                        completion(false)
                        return
                    }
                    print("Delete Done. Saved the updated conversation list for a user")
                    completion(true)
                })
            }
        }
    }
}



