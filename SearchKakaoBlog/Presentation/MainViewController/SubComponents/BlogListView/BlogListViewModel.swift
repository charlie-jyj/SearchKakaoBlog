//
//  BlogListViewModel.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/28.
//

import RxSwift
import RxCocoa

struct BlogListViewModel {
    let filterViewModel = FilterViewModel()  // header로 필터를 가지기 때문
    let blogdataList = PublishSubject<[BlogListCellData]>()
    let dataList: Driver<[BlogListCellData]>
    
    init() {
        self.dataList = blogdataList
            .asDriver(onErrorJustReturn: [])
    }
}
