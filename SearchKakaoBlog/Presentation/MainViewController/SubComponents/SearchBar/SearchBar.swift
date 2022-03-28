//
//  SearchBar.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/23.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

class SearchBar: UISearchBar {
    let disposeBag = DisposeBag()
    
    let searchButton = UIButton()
    
    //searchbar button tap event
    //let searchButtonTapped = PublishRelay<Void>()  // error를 받지 않는 PublishSubject의 Wrapper 클래스
    
    //searchbar 외부로 내보낼 event
    //var shouldLoadResult = Observable<String>.of("")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        attribute()
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bind(_ viewModel: SearchBarViewModel) {
        // searchbar search button tapped (keyboard return)
        // button tapped
        // observable merge
        
        // 2개의 sequence를 합치고 1개의 이벤트에 bind
        Observable
            .merge(
                self.rx.searchButtonClicked.asObservable(),
                searchButton.rx.tap.asObservable()
            )
            .bind(to: viewModel.searchButtonTapped)
            .disposed(by: disposeBag)
        
        // searchButton이 tap 되면 endEditing event 방출
        // endEditing은 custom된 이벤트이다.
        viewModel.searchButtonTapped
            .asSignal()
            .emit(to: self.rx.endEditing)
            .disposed(by: disposeBag)
        
        self.rx.text
            .bind(to: viewModel.queryText)
            .disposed(by: disposeBag)
    }
    
    // ui component 의 속성 결정
    private func attribute() {
        searchButton.setTitle("search", for: .normal)
        searchButton.setTitleColor(.systemBlue, for: .normal)
    }
    
    // addsubview 후 snapkit으로 constraint 지정
    private func layout() {
        addSubview(searchButton)
        searchTextField.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.trailing.equalTo(searchButton.snp.leading).offset(-12)
            $0.centerY.equalToSuperview()
        }
        
        searchButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(12)
        }
    }
}

// uiComponent를 rx화 하기 위한 extension
extension Reactive where Base: SearchBar {
    var endEditing: Binder<Void> {
        // base : Base object to extend
        return Binder(base) { base, _ in
            base.endEditing(true)
        }
    }
}
