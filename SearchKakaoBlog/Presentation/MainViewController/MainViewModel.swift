//
//  MainViewModel.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/28.
//

import UIKit
import RxSwift
import RxCocoa

struct MainViewModel {
    let disposeBag = DisposeBag()
    let blogListViewModel = BlogListViewModel()
    let searchBarViewModel = SearchBarViewModel()
    let alertActionTapped = PublishRelay<MainViewController.AlertAction>()
    let shouldPresentAlert: Signal<MainViewController.Alert>
    
    init(model: MainModel = MainModel()) {
        let blogResult = searchBarViewModel.shouldLoadResult
            .flatMapLatest(model.searchBlog)  // 받는 인자가 동일하기 때문에 이렇게 축약 가능
            .share()
        
        // share : returns an observable sequence that shares a single subscription to the underlying sequence,
        // and immediately upon subscription replays elements in bugger
        
        let blogValue = blogResult
            .compactMap(model.getBlogValue)
        
        let blogError = blogResult
            .compactMap(model.getBlogError)
        
        
        let cellData = blogValue
            .map(model.getBlogListCellData)
                
        let sortedType = alertActionTapped
            .filter {
                switch $0 {
                case .title, .datetime:
                    return true
                default:
                    return false
                }
            }
            .startWith(.title)
        
        Observable
            .combineLatest(
                sortedType,
                cellData,
                resultSelector: model.sort
            )
            .bind(to: blogListViewModel.blogdataList)
            .disposed(by: disposeBag)
        
        let alertForErrorMessage = blogError
            .map { message -> MainViewController.Alert in
                return (
                    title: "something gets wrong!",
                    message: message,
                    actions: [.confirm],
                    style: .alert)
            }
        
        let alertSheetForSorting = blogListViewModel.filterViewModel.sortButtonTapped  // button이 tapped 되었을 때,
            .map { _ -> MainViewController.Alert in
                return (
                    title: nil,
                    message: nil,
                    actions: [.title, .datetime, .cancel],
                    style:.actionSheet
                )
            }
        
        self.shouldPresentAlert = Observable
            .merge(
                alertForErrorMessage,
                alertSheetForSorting
            )
            .asSignal(onErrorSignalWith: .empty())
            
    }
}
