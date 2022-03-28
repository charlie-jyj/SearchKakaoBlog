//
//  FilterView.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/23.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

/// alter sheet를 올릴 수 있도록 event emit 하는 객체
class FilterView: UITableViewHeaderFooterView {
    let disposeBag = DisposeBag()
    let sortButton = UIButton()
    let bottomBorder = UIView()
    
    // FilterView 외부에서 관찰
    //let sortButtonTapped = PublishRelay<Void>()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        attribute()
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bind(_ viewModel: FilterViewModel) {
        sortButton.rx.tap
            .bind(to: viewModel.sortButtonTapped)
            .disposed(by: disposeBag)
    }
    
    private func attribute() {
        sortButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        bottomBorder.backgroundColor = .lightGray
    }
    
    private func layout() {
        [sortButton, bottomBorder]
            .forEach {
                addSubview($0)
            }
        
        sortButton.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.trailing.equalToSuperview().inset(12)
            $0.width.height.equalTo(28)
        }
        
        bottomBorder.snp.makeConstraints {
            $0.top.equalTo(sortButton.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(0.5)
        }
    }
}
