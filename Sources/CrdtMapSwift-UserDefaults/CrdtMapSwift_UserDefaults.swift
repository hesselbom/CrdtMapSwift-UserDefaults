import Foundation
import CrdtMapSwift

public class CrdtMapSwift_UserDefaults {
    public private(set) var isSynced = false
    private var onUpdateOrSnapshotDebounceTimer: Timer?
    private var onUpdateListenerId: UUID?
    private var onSnapshotListenerId: UUID?
    private var onSyncedCallbacks: [(() -> Void)?] = []
    private let key: String
    private let doc: CrdtMapSwift
    private let userDefaults: UserDefaults
    
    public var onUpdateOrSnapshotTimerCallback: (() -> Void)?
    
    public init(key: String, doc: CrdtMapSwift, userDefaults: UserDefaults = UserDefaults.standard) {
        self.key = key
        self.doc = doc
        self.userDefaults = userDefaults
        
        onUpdateListenerId = doc.on("update", { [weak self] _ in self?.onUpdateOrSnapshot() })
        onSnapshotListenerId = doc.on("snapshot", { [weak self] _ in self?.onUpdateOrSnapshot() })
        
        // Load from UserDefaults
        DispatchQueue.global(qos: .default).async { [weak self] in
            if let data = self?.userDefaults.object(forKey: key) as? Data {
                let snapshot = CrdtMapSwift.decodeSnapshot(data)
                self?.doc.apply(snapshot: snapshot)
            }
            
            self?.emitSynced()
        }
    }
    
    public func whenSynced(_ callback: (() -> Void)?) {
        if isSynced {
            callback?()
        } else {
            onSyncedCallbacks.append(callback)
        }
    }
    
    public func destroy() {
        if let onUpdateListenerId = onUpdateListenerId {
            doc.off("update", onUpdateListenerId)
        }
        if let onSnapshotListenerId = onSnapshotListenerId {
            doc.off("snapshot", onSnapshotListenerId)
        }
    }
    
    private func emitSynced() {
        isSynced = true
        for callback in onSyncedCallbacks {
            callback?()
        }
        onSyncedCallbacks.removeAll()
    }
    
    // Use same callback for both update and snapshot since we store full map
    private func onUpdateOrSnapshot() {
        // Ignore if not synced yet, to prevent unnecessary writing when just read
        if !isSynced {
            return
        }
        
        // Slight debounce to avoid unnecesarily many writes
        onUpdateOrSnapshotDebounceTimer?.invalidate()
        
        onUpdateOrSnapshotDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { [weak self] _ in
            if let userDefaults = self?.userDefaults, let doc = self?.doc, let key = self?.key {
                userDefaults.set(CrdtMapSwift.encode(snapshot: doc.getSnapshotFrom(timestamp: 0)), forKey: key)
            }
            
            self?.onUpdateOrSnapshotTimerCallback?()
            self?.onUpdateOrSnapshotTimerCallback = nil
        })
    }
}
