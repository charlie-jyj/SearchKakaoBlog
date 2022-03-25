//
//  MainViewController.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/22.
//

import UIKit
import RxCocoa
import RxSwift
import CoreMIDI
import simd

class MainViewController: UIViewController {
    let disposeBag = DisposeBag()
    let listView = BlogListView()
    let searchBar = SearchBar()
    
    let alertActionTapped = PublishRelay<AlertAction>()
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        bind()
        attribute()
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bind() {
        //rx
        // component event binding
        
        let blogResult = searchBar.shouldLoadResult
            .flatMapLatest { query in
                SearchBlogNetwork().searchBlog(query: query)
            }
            .share()
        
        // share : returns an observable sequence that shares a single subscription to the underlying sequence,
        // and immediately upon subscription replays elements in bugger
        
        let blogValue = blogResult
            .compactMap { data -> DKBlog? in
                guard case .success(let value) = data else { return nil }
                return value
            }
        
        let blogError = blogResult
            .compactMap { data -> String? in
                guard case .failure(let error) = data else { return nil }
                return error.localizedDescription
            }
        
        let cellData = blogValue
            .map { blog -> [BlogListCellData] in
                return blog.documents
                    .map { doc in
                        let thumbnailURL = URL(string: doc.thumbnail ?? "")
                        return BlogListCellData(
                            thumbnailURL: thumbnailURL,
                            name: doc.name,
                            title: doc.title,
                            dateTime: doc.datetime)
                    }
            }
        
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
            .combineLatest(sortedType, cellData) { type, data -> [BlogListCellData] in
                switch type {
                case .title:
                    return data.sorted { $0.title ?? "" < $1.title ?? ""}
                case .datetime:
                    return data.sorted { $0.dateTime ?? Date() > $1.dateTime ?? Date() }
                default:
                    return data
                }
            }
            .bind(to: listView.dataList)
            .disposed(by: disposeBag)
        
        let alertForErrorMessage = blogError
            .map { message -> Alert in
                return (
                    title: "something gets wrong!",
                    message: message,
                    actions: [.confirm],
                    style: .alert)
            }
        
        let alertSheetForSorting = listView.headerView.sortButtonTapped  // button이 tapped 되었을 때,
            .map { _ -> Alert in
                return (
                    title: nil,
                    message: nil,
                    actions: [.title, .datetime, .cancel],
                    style:.actionSheet
                )
            }
        
        Observable
            .merge(
                alertForErrorMessage,
                alertSheetForSorting
            )
            .asSignal(onErrorSignalWith: .empty())
            .flatMapLatest { alert -> Signal<AlertAction> in
                let alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: alert.style)
                return self.presentAlertController(alertController, actions: alert.actions)
             }
            .emit(to: alertActionTapped)
            .disposed(by: disposeBag)
        
       
    }
    
    private func attribute() {
        // view
        title = "다음 블로그 검색"
        view.backgroundColor = .white
    }
    
    private func layout() {
        //snapkit
        [searchBar, listView].forEach {
            view.addSubview($0)
        }
        
        searchBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }
        
        listView.snp.makeConstraints {
            $0.top.equalTo(searchBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
}

//Alert

extension MainViewController {
    typealias Alert = (
        title:String?,
        message: String?,
        actions: [AlertAction],
        style: UIAlertController.Style)
    
    enum AlertAction: AlertActionConvertible {
        case title, datetime, cancel
        case confirm
        
        var title: String {
            switch self {
            case .title:
                return "Title"
            case .datetime:
                return "Datetime"
            case .cancel:
                return "cancel"
            case .confirm:
                return "confirm"
            }
        }
        
        var style: UIAlertAction.Style {
            switch self {
            case .title, .datetime:
                return .default
            case .cancel, .confirm:
                return .cancel
            }
        }
    }
    
    // alert 생성을 위한 설정
    func presentAlertController<Action: AlertActionConvertible>(_ alertController: UIAlertController, actions: [Action]) -> Signal<Action> {
        if actions.isEmpty { return .empty() }
        return Observable
            .create { [weak self] observer in
                guard let self = self else { return Disposables.create() }
                for action in actions {
                    alertController.addAction(
                        UIAlertAction(
                            title: action.title,
                            style: action.style,
                            handler: { _ in
                                observer.onNext(action)
                                observer.onCompleted()
                            }))
                }
                self.present(alertController, animated: true, completion: nil)
                return Disposables.create {
                    alertController.dismiss(animated: true, completion: nil)
                }
            }
            .asSignal(onErrorSignalWith: .empty())
    }
}
