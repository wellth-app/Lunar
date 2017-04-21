# Lunar
An addition to Apollo for persistent data storage using CoreData.

Lunar provides an implementation of the `NormalizedCache` protocol in [Apollo](https://github.com/apollographql/apollo-ios) that uses CoreData for persistent storage.

### Usage
Lunar is meant to serve as a piece of the Apollo stack, connecting your app to a hands-off CoreData persistent storage layer:
```
/// Lunar sets up it's own CoreData stack and may throw a `LunarCache.Error`
/// if something goes wrong.
let lunarCache = try! LunarCache()


let apollo = ApolloClient(
  networkTransport: MyNetworkTransport(),
  store: ApolloStore(lunarCache)
)
```
