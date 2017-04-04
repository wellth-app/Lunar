import Apollo


extension GraphQLID {
    public static func encode(type: String, id: String) -> GraphQLID? {
        let string = type + ":" + id
        guard let data = string.data(using: .utf8) else { return nil }
        return data.base64EncodedString()
    }
    
    public static func decode(id: GraphQLID) -> (type: String, id: String)? {
        guard let data = Data(base64Encoded: id, options: Data.Base64DecodingOptions(rawValue: 0)),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        
        let components = string.components(separatedBy: ":")
        
        return (components[0], components[1])
    }
}
