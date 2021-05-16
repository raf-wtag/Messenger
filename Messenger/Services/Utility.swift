//
//  Utility.swift
//  Messenger
//
//  Created by Fahim Rahman on 16/5/21.
//

import Foundation

class Utility {
    
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}
