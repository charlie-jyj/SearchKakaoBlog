//
//  FilterViewModel.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/28.
//

import RxSwift
import RxCocoa

struct FilterViewModel {
    let sortButtonTapped = PublishRelay<Void>()
}
