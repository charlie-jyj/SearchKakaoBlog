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
