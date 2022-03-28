#  

## 구현

### 사용 library
- RxSwift
- Snapkit
- Kingfisher

### 사용 API
- kakao 

### RxSwift 

#### 😎 alert 구현
> 개인적으로 제일 이해하기 어려웠던 부분 정리

0. alertViewController 를 띄우는 건 MainViewController

1. filter view (table view header)에 존재하는 sort button의 tap은
sortButtonTapped라는 PublishRelay와 연결되어 있다.

```swift

    let sortButton = UIButton()
    let sortButtonTapped = PublishRelay<Void>()
    private func bind() {
        sortButton.rx.tap
            .bind(to: sortButtonTapped)
            .disposed(by: disposeBag)
    }

``` 
- rx.tap은 ControlEvent<Void>
- PublishRelay는 `.completed`, `.error` 를 발생하지 않고 Dispose되기 전까지 계속 작동하기 때문에 UI Event에 적절한 선택

2. button이 tapped 되었을 때, MainViewController는 alertActionTapped에 event를 emit

```swift
    let alertActionTapped = PublishRelay<AlertAction>()
    private func bind() {
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

```

- button이 tap 되었을 때 미리 지정한 Alert (typealias) 로 sequence를 가공한다.
- Signal은 UI 버전의 PublishSubject 라고 이해한다.
- emit은 observable이 이벤트를 방출하는 것 (create subscription)
- alert action 이 emit되면 alertActionTapped (Relay)가 받는다.

3. 여기서 presentAlertController 함수는 무엇인가? 

```swift
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
    
```

```swift

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
```

- button이 tapped 될 때마다 UIAlertController를 통해 alert 를 present 해주기 위해 만들어진 함수
- 또한 alert view가 어떻게 보여질 지 결정한다. (style 등)
- signal을 반환한다.

#### 🤩 Result
```swift
@frozen public enum Result<Success, Failure> where Failure : Error

    /// A success, storing a `Success` value.
    case success(Success)

    /// A failure, storing a `Failure` value.
    case failure(Failure)

```

#### 🥸 search event 구현
> event의 흐름을 정리해본다.

1. UISearchBar class 안에서 search button이 tapped 될 경우 
```swift
        var shouldLoadResult = Observable<String>.of("")

        searchButtonTapped
            .asSignal()
            .emit(to: self.rx.endEditing) 
            .disposed(by: disposeBag)
            
        self.shouldLoadResult = searchButtonTapped
            .withLatestFrom(self.rx.text) { $1 ?? "" }
            .filter { !$0.isEmpty }
            .distinctUntilChanged()
```

- emit endEditing event (extension Reactive where Base: SearchBar)
- withLatestFrom 
    - Elements emitted by self before the second source has emitted any values will be omitted.
    ```swift
        public func withLatestFrom<Source: ObservableConvertibleType, ResultType>(_ second: Source, resultSelector: @escaping (Element, Source.Element) throws -> ResultType) -> Observable<ResultType> {
        WithLatestFrom(first: self.asObservable(), second: second.asObservable(), resultSelector: resultSelector)
    }
    ```

2. MainViewController 에서 SearchBar의 text를 query로 받아서 session.rx.data (Single)을 받아온다.

```swift
    func searchBlog(query: String) -> Single<Result<DKBlog, SearchNetworkError>> {
            ...
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

```
- SearchNetworkError는 사용자 정의한 Error

```swift
        let blogResult = searchBar.shouldLoadResult
            .flatMapLatest { query in
                SearchBlogNetwork().searchBlog(query: query)
            }
            .share()
        
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

```
- share() 
    - returns an observable sequence that shares a single subscription to the underlying sequence

3. success 시 data 처리

```swift
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
```
- combineLatest
    ```swift
    
    static func combineLatest<O1, O2>(_ source1: O1, _ source2: O2, resultSelector: @escaping (O1.Element, O2.Element) throws -> [BlogListCellData]) -> Observable<[BlogListCellData]> where O1 : ObservableType, O2 : ObservableType
    
    ```
- listView.dataList 는 PublishSubject<[BlogListCellData]>()


4. failure 시 data 처리

```swift
    let blogError = blogResult
        .compactMap { data -> String? in
            guard case .failure(let error) = data else { return nil }
            return error.localizedDescription
        }
        
    let alertForErrorMessage = blogError
        .map { message -> Alert in
            return (
                title: "something gets wrong!",
                message: message,
                actions: [.confirm],
                style: .alert)
        }
        
    Observable
    .merge(
        alertForErrorMessage,
        alertSheetForSorting
    )
    .asSignal(onErrorSignalWith: .empty())
```
- merge : merge 할 sequence는 type이 동일해야 한다.

### 🌟 새롭게 알게 된 것

#### ✨ Alert vs ActionSheet

##### Action Sheets
<img src="https://developer.apple.com/design/human-interface-guidelines/ios/images/action-sheets_2x.png">

- An action sheet presents two or more choices related to an intentional user action
- on smaller screens, an action sheet slides up from the bottom of the screen; on larger screens, an actio nsheet appears all at once as a popover.

<https://developer.apple.com/design/human-interface-guidelines/ios/views/action-sheets/>

- 적용 방법은 alert와 다르지 않다.

```swift
let alert = UIAlertController(title: "My Alert", message: "This is an alert.", preferredStyle: .alert) 
alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in 
NSLog("The \"OK\" alert occured.")
}))
self.present(alert, animated: true, completion: nil)
```

<https://developer.apple.com/documentation/uikit/uialertcontroller>

#### ✨ info.plist에 URL types 추가하기
- Document Role : Editor
    - acc can do with the URL reading and writing
- URL Schemes

<https://stackoverflow.com/questions/16598352/in-xcode-under-info-tab-whats-role-for-in-url-types-section>


#### ✨ Decodable struct에서 init 사용하기 

```swift
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try? values.decode(String?.self, forKey: .title)
        self.name = try? values.decode(String?.self, forKey: .name)
        self.thumbnail = try? values.decode(String?.self, forKey: .thumbnail)
        self.datetime = Date.parse(values, key: .datetime)  
    }

```
- String으로 받은 것을 => Date로 변환하기 위한 init이다.
- self.datetime을 initialize 하면 다른 property도 exhaustive 하게 모두 init 해줘야 하기 때문에

```swift
func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey
```
- returns the data stored in this decoder *as represented in a container* keyed by the given key type 
- type: the key type to use for the container

```swift
func decode<T>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T where T : Decodable
```
- type: the type of value to decode
- key : the key that the decoded value is associated with

#### ✨ NSMutableURLRequest vs URLRequest

- they are different classes but they are intended to provide the same functionality.
- the NS version is more of a legacy APY that was a holdover from Objective-C 
- NSMutableURLRequest is a subclass of NSURLRequest that allows you to change the request’s properties.
<>
<https://stackoverflow.com/questions/44770724/what-is-the-difference-between-nsurlrequest-and-urlrequest-in-swift>

#### 👑 MVVM 

- 현실 Cocoa MVC의 한계: View + Controller 의 불분명한 경계 
- 비대한 ViewController => 순수한 MVC 패턴의 장점이 발휘되기 어려움
    - notification 연산, delegate, 비지니스 로직 모두 가짐
    - massive view controller
- retired document 

<img src="https://wojciechkulik.pl/wp-content/uploads/2019/07/mvvm.png">


1. Model
2. ViewModel
    - 자신의 Model을 소유하고 업데이트 한다
    - 데이터 사용자 액션 바인딩
    ```swift
    let tappedButton = PublishRelay<Void>()  // 이벤트 구독
    let combo: Signal<String>  // 방출할 sequence
    
    //...
    
    combo = tappedButton
    .map { _ in
        "abcd"
    }
    .asSignal(onErrorJustReturn: "")
    ```
3. View
    - 자신의 ViewModel을 소유한다 (따라서 ViewModel은 View를 알지 못해도 괜찮다.)
    
    ```swift
    
    // event trigger
    button.rx.tap
    .bind(to: viewModel.tappedButton)
    .disposed(by: disposeBag)
    
    
    // sequence를 어떻게 보여줄지만 결정
    viewModel.combo
    .emit(onNext: {
        print($0)
    })
    .disposed(by: disposeBag)
    ```

- 단방향 개발이 용이해진다 + Rx 결합 시 시너지 증가
    - view 사용자 입력 observable
    - viewmodel이 observable을 subscribe(bind to) 하는 양상 (Observer)
    - viewmodel의 stream을 rx의 operator로 대체하여 코드 수를 줄이고 가독성 증가
    - rx는 view와 viewmodel 사이에서 접착제 역할
- Cocoa Framework 의존도 낮아짐
- 순수한 비즈니스 로직 보존, 로직 재사용 가능
- ViewModel은 View를 몰라도 되는 장점

