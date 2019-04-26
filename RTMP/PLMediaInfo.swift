//
//  PLMediaInfo.swift
//  RTMP
//
//  Created by JLM on 2019/4/25.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit

class PLMediaInfo: Codable {
    let mimeType: String?
    let putTime: CLongLong?
    let type: Int?
    let fileSize: CLongLong?
    let mediaHash: String?
    let headerImg: String?
    let thumbURL: String?
    let videoURL: String?
    let endUser: String?
    let detailDesc: String?
    let name: String?
}

extension UIView {
    public func hideFullLoading() {
        
    }
    
    public func showFullLoading() {
        
    }
}
