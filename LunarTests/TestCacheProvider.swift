import Apollo
import Lunar

enum TestCacheProvider {
    /// Execute a test block rather than return a cache synchronously, since cache setup may be
    /// asynchronous at some point.
    static func withCache(initialRecords: RecordSet? = nil, fileURL: URL? = nil, execute test: (NormalizedCache) -> ()) {
        let cache = try! LunarCache(
            cacheURL: fileURL ?? temporarySQLiteFileURL(),
            useMainQueueContext: true
        )
        
        if let initialRecords = initialRecords {
            _ = cache.merge(records: initialRecords) // This is synchronous
        }
        
        test(cache)
        
        try! cache.purge()
    }
    
    static func temporarySQLiteFileURL() -> URL {
        return URL.temporaryDirectoryURL()
    }
}
