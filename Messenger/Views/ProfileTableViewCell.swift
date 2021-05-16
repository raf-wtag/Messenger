//
//  ProfileTableViewCell.swift
//  Messenger
//
//  Created by Fahim Rahman on 5/5/21.
//

import UIKit

class ProfileTableViewCell: UITableViewCell {
    
    static var identifier = "profileTableviewCell"

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    public func setTableviewCellUp(with viewModel: ProfileViewModel) {
        self.textLabel?.text = viewModel.title
        
        switch viewModel.profileType {
        case .info:
            self.selectionStyle = .none
        case .logout:
            self.textLabel?.textColor = .red
            self.textLabel?.textAlignment = .center
        }
    }

}
