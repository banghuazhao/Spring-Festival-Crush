//
//  MoreAppsHeaderCell.swift
//  Countdown Days
//
//  Created by Banghua Zhao on 2021/1/24.
//  Copyright © 2021 Banghua Zhao. All rights reserved.
//

import UIKit

class MoreAppsHeaderCell: UITableViewCell {
    lazy var label = UILabel().then { label in
        label.text = "Apps".localized()
        label.font = UIFont.title
        label.numberOfLines = 0
        label.textColor = .black
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        tintColor = .clear
        selectionStyle = .none
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
            make.top.equalToSuperview().inset(20)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
