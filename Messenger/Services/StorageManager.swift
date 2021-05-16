//
//  StorageManager.swift
//  Messenger
//
//  Created by Fahim Rahman on 22/4/21.
//

import Foundation
import Firebase

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    public typealias uploadPictureCompletionType = (Result<String, Error>) -> Void
    
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping uploadPictureCompletionType) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: {metadata, error in
            guard error == nil else {
                print("Failed to upload photo in firebase")
                completion(.failure(storageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    print("Download Failed from Firebase")
                    completion(.failure(storageErrors.failedToDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Profile Picture Download URL is - ", urlString)
                completion(.success(urlString))
            })
            
        })
    }
    
    public enum storageErrors: Error {
        case failedToUpload
        case failedToDownloadURL
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> ()) {
        let reference = storage.child(path)
        reference.downloadURL(completion: {url, error in
            guard let url = url, error == nil else {
                completion(.failure(storageErrors.failedToDownloadURL))
                return
            }
            completion(.success(url))
        })
    }
    
    public func uploadPhotoImage(with data: Data, fileName: String, completion: @escaping uploadPictureCompletionType) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata, error in
            guard error == nil else {
                print("Failed to upload photo in firebase")
                completion(.failure(storageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    print("Download Failed from Firebase")
                    completion(.failure(storageErrors.failedToDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download URL is - ", urlString)
                completion(.success(urlString))
            })
            
        })
    }
    
    public func uploadVideoMessage(with urlVideo: URL, fileName: String, completion: @escaping uploadPictureCompletionType) {
        
        if let videoData = NSData(contentsOf: urlVideo) as Data? {
            storage.child("message_videos/\(fileName)").putData(videoData, metadata: nil) { [weak self] metadata, error in
                guard error == nil else {
                    print("Failed to upload photo in firebase")
                    completion(.failure(storageErrors.failedToUpload))
                    return
                }
                
            //        storage.child("message_videos/\(fileName)").putFile(from: urlVideo, metadata: nil) { [weak self] metadata, error in
            //            guard error == nil else {
            //                completion(.failure(storageErrors.failedToUpload))
            //                return
            //            }
                
                self?.storage.child("message_videos/\(fileName)").downloadURL(completion: {url, error in
                    guard let url = url else {
                        print("Video Download Failed from Firebase")
                        completion(.failure(storageErrors.failedToDownloadURL))
                        return
                    }
                    
                    let urlString = url.absoluteString
                    print("Video Download URL is - ", urlString)
                    completion(.success(urlString))
                })
            }
        }
    }
}
