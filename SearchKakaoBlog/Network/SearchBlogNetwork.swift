//
//  SearchBlogNetwork.swift
//  SearchKakaoBlog
//
//  Created by 정유진 on 2022/03/25.
//

import Foundation
import RxSwift

enum SearchNetworkError: Error {
    case invalidURL
    case invalidJSON
    case networkError
}

class SearchBlogNetwork {
    private let session: URLSession
    let api = SearchBlogAPI()

    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func searchBlog(query: String) -> Single<Result<DKBlog, SearchNetworkError>> {
        // Result<Success, Failure> where Failure: Error
        guard let url = api.searchBlog(query: query).url else { return .just(.failure(.invalidURL)) }
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK 7d76dd4698178f11c05418607b87e626", forHTTPHeaderField: "Authorization")
        
        return session.rx.data(request: request as URLRequest)
            .map { data in
                do {
                    let blogData = try JSONDecoder().decode(DKBlog.self, from: data)
                    return .success(blogData)
                } catch {
                    return .failure(.invalidJSON)
                }
            }
            .catch { _ in
            .just(.failure(.networkError))
            }
            .asSingle()
    }
    
}
