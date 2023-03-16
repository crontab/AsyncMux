# AsyncMux
### Asnychronous multiplexer utilities with caching for Swift

*This is an evolution of the older [Multiplexer library](https://github.com/crontab/Multiplexer), now refactored under Swift's structured concurrency.*

#### Table of contents

- [Introduction](#intro)
- [Multiplexer](#multiplexer)

<a name="intro"></a>
## 1. Introduction

The Swift AsyncMux utility suite provides a browser-like request/caching layer for network objects, based on Swift's Sutrctured Concurrency (`async/await`) and partly callbacks.

Here are the scenarios that are covered by the Multiplexer utilities:

**Scenario 1:** execute an async block, typically a network call, and return the result to one or more callers. Various parts of your app may be requesting e.g. the user's profile simultaneously at program startup; you want to make sure the network request is performed only once, then the result is returned to all parts of the app that requested the object. We call it **multiplexing** (not to be confused with multiplexing in networking).

Additionally, provide caching of the result in memory for a certain period of time. Subsequent calls to this multiplexer may return the cached result unless some time-to-live (TTL) elapses, in which case a new network call is made transparently.

This multiplexer can be configured to use disk caching in addition to memory caching. Another possibility is to have this multiplexer return a previously known result regardless of its TTL if the latest network call resulted in one of the specific types of failures, such as network connectivity errors.

Support "soft" and "hard" refreshes, like the browser's Cmd-R and related functions.

**Scenario 2:** have a dictionary of multiplexers that request and cache objects of the same type by their symbolic ID, e.g. user profiles.

**Scenario 3:** provide file downloading, multiplexing and disk caching. In addition to disk caching, some limited number of media objects can be cached in memory for faster access.


<a name="multiplexer"></a>
## Multiplexer<T>

`Multiplexer<T>` is an asynchronous caching facility for client apps. Each multiplxer instance can manage retrieval, multiplexing and caching of one object of type `T: Codable & Sendable`, therefore it is best to define each multiplexer instance in your app as a singleton. Also note that `Multiplexer` itself is an actor, therefore all its public methods are asynchronous.

For each multiplexer singleton you define a block that implements asynchronous retrieval of an object, which may be e.g. a network request to your backend system.

A multiplexer singleton guarantees that there will only be one fetch/retrieval operation made, and that subsequently a memory-cached object will be returned to the callers of its `request()` method , unless the cached object expires according to the `timeToLive` setting (defaults to 30 minutes). Additionally, Multiplexer can store the object on disk - see [`MuxRepository`](#mux-repository) and also the discussion on `request()` below.

Suppose you have a `UserProfile` structure and a method for retrieving the current user's profile object from the backend, whose signature looks like this:

```swift
    class Backend {
        static func fetchMyProfile() async throws -> UserProfile
    }
```

Then an instantiation of a multiplexer singleton will look like:

```swift
    let myProfile = Multiplexer<UserProfile>(onFetch: {
        return try await Backend.fetchMyProfile()
    })
```

Or even shorter:

```swift
    let myProfile = Multiplexer(onFetch: Backend.fetchMyProfile)
```

You can use `myProfile` to fetch the profile object by calling the `request()` method like so:

```swift
    try {
        let profile = try await myProfile.request()
    }
    catch {
        print("Coudn't retrieve user profile:", error)
    }
```

When called for the first time, `request()` calls your `onFetch` block, returns it asynchronously to the caller (or throws an error), and also caches the result in memory. Subsequent calls to `request()` will return immediately with the stored object.

Most importantly, `request()` can handle multiple simultaneous calls and ensures only one `onFetch` operation is initiated at a time.

### Caching

By default, `Multiplexer<T>` can store objects as JSON files in the local cache directory. This is done by explicitly calling `save()` on the multiplexer object, or alternatively `saveAll()` on the global repository `MuxRepository` if the multiplexer object is registered there. Registration can be done like so:
    
```swift
    let myProfile = Multiplexer<UserProfile> {
        return try await Backend.fetchMyProfile()
    }
    .register()
```

The objects stored on disk can be reused if your `onFetch` fails due to a connectivity problem. You can additionally tell the multiplexer to ignore the error and fetch the cached object by throwing a `SilencableError` in your `onFetch` method.
    
For the memory cache, the expiration logic is defined by a global constant `timeToLive`, which defaults to 30 minutes (currently not overridable - to be changed later). The storage method is also hardcoded but will be possible to override in the future releases.

At run time, you can invalidate the cached object using one of the following methods:

- "Soft refresh": chain the `refresh()` method with a call to `request()`: the multiplexer will attempt to fetch the object again, but will not discard the existing cached objects in memory or on disk. In case of a silencable error the older cached object will be used again as a result.
- "Hard refresh": call `clear()` to discard both memory and disk caches for a given object. The next call to `request()` will attempt to fetch the object and will fail in case of an error.

See also:

- `init(cacheKey: String? = nil, onFetch: @escaping (@escaping @Sendable () async throws -> T) -> Void)`
- `request()`
- `refresh()`
- `clear()`
- `save()`
- [`MultiplexerMap`](#multiplexer-map)
- [`MuxRepository`](#mux-repository)

More detailed descriptions on each method can be found in the source file [Multiplexer.swift](AsyncMux/Sources/Multiplexer.swift).





Weather API used in the demo app: [Open Meteo](https://open-meteo.com/en/docs)
