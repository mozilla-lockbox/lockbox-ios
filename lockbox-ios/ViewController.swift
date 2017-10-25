import UIKit
import WebKit
import Foundation
import RxSwift

class ViewController: UIViewController {
    var webView: WebView!
    var dataStore: DataStore!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let contentController = WKUserContentController()
        let webConfig = WKWebViewConfiguration()

        webConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webConfig.preferences.javaScriptEnabled = true
        webConfig.userContentController = contentController

        self.webView = WebView(frame: .zero, configuration: webConfig)

        self.view.addSubview(self.webView)

        self.dataStore = DataStore(webview: self.webView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func initClicked(_ sender: Any) {
        self.dataStore.initialize(password: "password")
                .subscribe(onCompleted: {
                            print("initialized!") },
                        onError: { error in
                            print(error)
                        })
                .disposed(by: self.disposeBag)
    }

    @IBAction func unlockClicked(_ sender: Any) {
        self.dataStore.unlock(password: "password")
                .subscribe(onCompleted: {
                    print("unlocked!!") },
                        onError: { error in
                            print(error)
                        })
                .disposed(by: self.disposeBag)
    }

    @IBAction func listClicked(_ sender: Any) {
        self.dataStore.keyList().subscribe(onSuccess: { list in
                    for item in list {
                        print(item)
                    }
                }, onError: { error in
                    print("error: \(error)")
                })
                .disposed(by: disposeBag)
    }
}
