//
//  AppItem.swift
//  Spring Festival Crush
//
//  Created by Banghua Zhao on 1/1/21.
//  Copyright © 2021 Banghua Zhao. All rights reserved.
//

import UIKit

struct AppItem: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    let icon: UIImage?
    let url: URL?
    init(title: String, detail: String, icon: UIImage?, url: URL?) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.url = url
    }
}
