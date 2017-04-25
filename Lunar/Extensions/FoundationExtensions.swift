extension URL {
    static func documentsDirectoryURL() -> URL {
        #if os(tvOS)
            return temporaryDirectoryURL()
        #else
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        #endif
    }
    
    static func temporaryDirectoryURL() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
    }
}
