//
//  AlertActionConvertible.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/23.
//

import UIKit

protocol AlertActionConvertible {
    var title: String { get }
    var style: UIAlertAction.Style { get }
}
