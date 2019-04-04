/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import FxAClient
import RxSwift
import RxCocoa
import RxOptional
import Logins
import SwiftyJSON
import SwiftKeychainWrapper

enum SyncError: Error {
    case CryptoInvalidKey
    case CryptoMissingKey
    case Crypto
    case Locked
    case Offline
    case Network
    case NeedAuth
    case Conflict
    case AccountDeleted
    case AccountReset
    case DeviceRevoked
}

enum SyncState: Equatable {
    case NotSyncable, ReadyToSync, Syncing, Synced, Error(error: SyncError)

    public static func ==(lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (NotSyncable, NotSyncable):
            return true
        case (ReadyToSync, ReadyToSync):
            return true
        case (Syncing, Syncing):
            return true
        case (Synced, Synced):
            return true
        case (Error, Error):
            return true
        default:
            return false
        }
    }
}

enum LoginStoreState: Equatable {
    case Unprepared, Locked, Unlocked, Errored(cause: LoginStoreError)

    public static func ==(lhs: LoginStoreState, rhs: LoginStoreState) -> Bool {
        switch (lhs, rhs) {
        case (Unprepared, Unprepared): return true
        case (Locked, Locked): return true
        case (Unlocked, Unlocked): return true
        case (Errored, Errored): return true
        default:
            return false
        }
    }
}

public enum LoginStoreError: Error {
    // applies to just about every function call
    case Unknown(cause: Error?)
    case NotInitialized
    case AlreadyInitialized
    case VersionMismatch
    case CryptoInvalidKey
    case CryptoMissingKey
    case Crypto
    case InvalidItem
    case Locked
}

class BaseDataStore {
    internal var disposeBag = DisposeBag()
    private var listSubject = BehaviorRelay<[LoginRecord]>(value: [])
    private var syncSubject = ReplaySubject<SyncState>.create(bufferSize: 1)
    internal var storageStateSubject = ReplaySubject<LoginStoreState>.create(bufferSize: 1)

    private let keychainWrapper: KeychainWrapper
    internal let userDefaults: UserDefaults
    internal let dispatcher: Dispatcher
    private let application: UIApplication
    internal var syncUnlockInfo: SyncUnlockInfo?
    internal let accountStore: BaseAccountStore

    internal var loginsStorage: LoginsStorage?

    public var list: Observable<[LoginRecord]> {
        return self.listSubject.asObservable()
    }

    public var syncState: Observable<SyncState> {
        return self.syncSubject.asObservable()
    }

    public var locked: Observable<Bool> {
        return self.storageState.map { $0 == LoginStoreState.Locked }
    }

    public var storageState: Observable<LoginStoreState> {
        return self.storageStateSubject.asObservable()
    }

    // From: https://github.com/mozilla-lockbox/lockbox-ios-fxa-sync/blob/120bcb10967ea0f2015fc47bbf8293db57043568/Providers/Profile.swift#L168
    internal static var loginsKey: String? {
        let key = "sqlcipher.key.logins.db"
        let keychain = KeychainWrapper.sharedAppContainerKeychain
        if keychain.hasValue(forKey: key) {
            return keychain.string(forKey: key)
        }

        let Length: UInt = 256
        let secret = Bytes.generateRandomBytes(Length).base64EncodedString(options: [])
        keychain.set(secret, forKey: key, withAccessibility: .afterFirstUnlock)
        return secret
    }

    var unlockInfo: SyncUnlockInfo?

    init(dispatcher: Dispatcher = Dispatcher.shared,
         keychainWrapper: KeychainWrapper = KeychainWrapper.standard,
         userDefaults: UserDefaults = UserDefaults(suiteName: Constant.app.group)!,
         accountStore: BaseAccountStore = AccountStore.shared,
         application: UIApplication = UIApplication.shared) {
        self.keychainWrapper = keychainWrapper
        self.userDefaults = userDefaults
        self.application = application
        self.accountStore = accountStore

        self.dispatcher = dispatcher

        self.initializeLoginsStorage()

        dispatcher.register
                .filterByType(class: DataStoreAction.self)
                .subscribe(onNext: { action in
                    print("Sync15 Action: \(action)")
                    switch action {
                    case .updateCredentials(let oauthInfo, let fxaProfile):
                        self.updateCredentials(oauthInfo, fxaProfile: fxaProfile)
                    case .reset:
                        self.reset()
                    case .sync:
                        self.sync()
                    case let .touch(id:id):
                        self.touch(id: id)
                    case .lock:
                        self.lock()
                    case .unlock:
                        self.unlock()
                    }
                })
                .disposed(by: self.disposeBag)

        dispatcher.register
                .filterByType(class: LifecycleAction.self)
                .subscribe(onNext: { action in
                    switch action {
                    case .background:
                        print("backgrounding")
//                        self.loginsStorage?.doDestroy()
//                        self.profile.syncManager?.applicationDidEnterBackground()
//                        var taskId = UIBackgroundTaskIdentifier.invalid
//                        taskId = application.beginBackgroundTask (expirationHandler: {
//                            self.profile.shutdown()
//                            application.endBackgroundTask(taskId)
//                        })
                    case .foreground:
//                        self.profile.syncManager?.applicationDidBecomeActive()
                        self.initializeLoginsStorage()
                        self.sync()
                        self.handleLock()
                    case .upgrade(let previous, _):
                        if previous <= 2 {
                            self.handleLock()
                        }
                    case .shutdown:
                        self.shutdown()
                    default:
                        break
                    }
                })
                .disposed(by: disposeBag)

        self.syncState
                .subscribe(onNext: { state in
                    if state == .Synced {
                        self.updateList()
                    } else if state == .NotSyncable {
                        self.makeEmptyList()
                    }
                })
                .disposed(by: self.disposeBag)

        self.storageState
                .subscribe(onNext: { state in
                    if state == .Unlocked {
                        self.updateList()
                    } else if state == .Locked {
                        self.makeEmptyList()
                    }
                })
                .disposed(by: self.disposeBag)

        self.setInitialState()
        self.initialized()
    }
    
    public func initialized() {
        fatalError("not implemented!")
    }

    public func get(_ id: String) -> Observable<LoginRecord?> {
        return self.listSubject
                .map { items -> LoginRecord? in
                    return items.filter { item in
                        return item.id == id
                    }.first
                }.asObservable()
    }

    public func unlock() {
        func performUnlock() {
            do {
                if let loginsKey = BaseDataStore.loginsKey {
                    guard let loginsStorage = self.loginsStorage else { return }
                    if loginsStorage.isLocked() {
                        try loginsStorage.unlock(withEncryptionKey: loginsKey)
                        self.storageStateSubject.onNext(.Unlocked)
                        self.doSync()
                    }
                }
            } catch let error {
                print("LoginsError: \(error)")
            }
        }

        self.storageState
            .take(1)
            .subscribe(onNext: { state in
                if state == .Locked {
                    performUnlock()
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func shutdown() {
//        do {
//            try self.loginsStorage?.doDestroy()
//        } catch let error {
//            print("Sync15: \(error)")
//        }
    }

    internal func doSync() {
        if let syncUnlockInfo = self.syncUnlockInfo {
            self.syncSubject.onNext(SyncState.Syncing)

            DispatchQueue.global(qos: .background).async {
                do {
                    try self.loginsStorage?.sync(unlockInfo: syncUnlockInfo)
                    self.syncSubject.onNext(SyncState.Synced)
                } catch let error {
                    print("Sync15 Sync Error: \(error)")
                }
            }
        }
    }
}

extension BaseDataStore {
    public func updateCredentials(_ oauthInfo: SyncUnlockInfo, fxaProfile: FxAClient.Profile) {
        // what do we need to do in here to link account info with the logins storage?
    }
}

extension BaseDataStore {
    public func touch(id: String) {
        do {
            try self.loginsStorage?.touch(id: id)
        } catch let error {
            print("Sync15: \(error)")
        }
    }
}

extension BaseDataStore {
    private func reset() {
        do {
            try self.loginsStorage?.reset()
        } catch let error {
            print("Sync15: \(error)")
        }
    }
}

extension BaseDataStore {
    func lock() {
        guard let loginsStorage = self.loginsStorage else { return }

        if loginsStorage.isLocked() {
            return
        }

        do {
            try loginsStorage.lock()
            self.storageStateSubject.onNext(.Locked)
        } catch let error {
            print("Sync15: \(error)")
        }
    }
}

extension BaseDataStore {
    public func sync() {
        guard let loginsStorage = self.loginsStorage else { return }

        if loginsStorage.isLocked() {
            return
        }

        self.doSync()
    }


    private func updateList() {
        do {
            if let loginsStorage = self.loginsStorage {
                if loginsStorage.isLocked() {
                    return
                }

                let loginRecords = try loginsStorage.list()
                self.listSubject.accept(loginRecords)
//                let oldStyleLogins = loginRecords.map { (record: LoginRecord) -> Login in
//                    return Login(guid: record.id, hostname: record.hostname, username: record.username ?? "", password: record.password)
//                }
//                self.listSubject.accept(oldStyleLogins)
            }
        } catch let error {
            print("Sync15: \(error)")
        }
    }

    private func makeEmptyList() {
        self.listSubject.accept([])
    }
}

extension BaseDataStore {
//    public func remove(id: String) {
//        self.profile.logins.removeLoginByGUID(id) >>== {
//            self.syncSubject.onNext(.ReadyToSync)
//        }
//    }

//    public func add(item: LoginData) {
//        self.profile.logins.addLogin(item) >>== {
//            self.syncSubject.onNext(.ReadyToSync)
//        }
//    }
}

// initialization
extension BaseDataStore {
    private func initializeLoginsStorage() {
        let filename = "logins.db"

        let profileDirName = "profile.lockbox-profile)"

        // Bug 1147262: First option is for device, second is for simulator.
        var rootPath: String
        let sharedContainerIdentifier = AppInfo.sharedContainerIdentifier
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedContainerIdentifier) {
            rootPath = url.path
        } else {
            print("Unable to find the shared container. Defaulting profile location to ~/Documents instead.")
            rootPath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        }

        let files = FileAccessor(rootPath: URL(fileURLWithPath: rootPath).appendingPathComponent(profileDirName).path)
        let file = URL(fileURLWithPath: (try! files.getAndEnsureDirectory())).appendingPathComponent(filename).path

        self.loginsStorage = LoginsStorage(databasePath: file)
    }

//    private func initializeProfile() {
//        self.profile.syncManager?.applicationDidBecomeActive()
//
//        self.fxaLoginHelper.application(UIApplication.shared, didLoadProfile: profile)
//    }

    private func setInitialState() {
        self.accountStore.account
            .take(1)
            .subscribe(onNext: { (account) in
                if account == nil {
                    self.storageStateSubject.onNext(.Unprepared)
                    self.syncSubject.onNext(.NotSyncable)
                } else {
                    self.syncSubject.onNext(.ReadyToSync)

                    // default to locked state on initialized
                    self.storageStateSubject.onNext(.Locked)
                    self.handleLock()
                }
            }).disposed(by: self.disposeBag)
//        guard profile.hasSyncableAccount() else {
//            if !profile.hasAccount() {
//                // first run.
//                self.storageStateSubject.onNext(.Unprepared)
//            }
//
//            self.syncSubject.onNext(.NotSyncable)
//            return
//        }
//        self.syncSubject.onNext(.ReadyToSync)
//
//        // default to locked state on initialized
//        self.storageStateSubject.onNext(.Locked)
//        self.handleLock()
    }

    internal func handleLock() {
        Observable.combineLatest(
            self.userDefaults.onAutoLockTime,
            self.userDefaults.onForceLock)
            .take(1)
            .subscribe(onNext: { autoLockSetting, forceLock in
                if forceLock {
                    self.lock()
                } else if autoLockSetting == .Never {
                    self.unlock()
                } else {
                    let date = NSDate(
                        timeIntervalSince1970: self.userDefaults.double(
                            forKey: UserDefaultKey.autoLockTimerDate.rawValue))

                    if date.timeIntervalSince1970 > 0 && date.timeIntervalSinceNow > 0 {
                        self.unlock()
                    } else {
                        self.lock()
                    }
                }
            })
        .disposed(by: self.disposeBag)
    }
}
