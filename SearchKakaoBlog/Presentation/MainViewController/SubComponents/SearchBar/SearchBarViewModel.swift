//
//  SearchBarViewModel.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/28.
//

import RxSwift
import RxCocoa

struct SearchBarViewModel {
    let queryText = PublishRelay<String?>()
    let searchButtonTapped = PublishRelay<Void>()
    var shouldLoadResult = Observable<String>.of("")
    
    init() {
        shouldLoadResult = searchButtonTapped
            .withLatestFrom(queryText) { $1 ?? "" }
            .filter { !$0.isEmpty }
            .distinctUntilChanged()
    }
}
