//
//  MainViewController.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/22.
//

import UIKit
import RxCocoa
import RxSwift

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
        let alertSheetForSorting = listView.headerView.sortButtonTapped  // button이 tapped 되었을 때,
            .map { _ -> Alert in
                return (
                    title: nil,
                    message: nil,
                    actions: [.title, .datetime, .cancel],
                    style:.actionSheet
                )
            }
        
        alertSheetForSorting
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
