//
//  BlogListView.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/23.
//

import UIKit
import RxSwift
import RxCocoa

class BlogListView: UITableView {
    let disposeBag = DisposeBag()
    
    // custom header
    let headerView = FilterView(
        frame: CGRect(
            origin: .zero,
            size: CGSize(width: UIScreen.main.bounds.width, height: 50)))
    
    // MainViewController => BlogListView
    //let dataList = PublishSubject<[BlogListCellData]>()
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        attribute()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
   func bind(_ viewModel: BlogListViewModel) {
       headerView.bind(viewModel.filterViewModel)
        // delegate rx 
        viewModel.dataList
            .drive(self.rx.items) { tableview, idx, celldata in
                let indexpath = IndexPath(row: idx, section: 0)
                let cell = tableview.dequeueReusableCell(withIdentifier: "BlogListCell", for: indexpath) as! BlogListCell
                cell.setData(celldata)
                return cell
            }
            .disposed(by: disposeBag)
    }
    
    private func attribute() {
        self.backgroundColor = .white
        self.register(BlogListCell.self, forCellReuseIdentifier: "BlogListCell")
        self.separatorStyle = .singleLine
        self.rowHeight = 100
        self.tableHeaderView = headerView
    }
}
