# AsyncMux
### Asynchronous caching and multiplexing layer for modern Swift client apps

#### Table of contents

- [Introduction](#intro)
- [Multiplexer](#multiplexer)
- [MultiplexerMap](#multiplexer-map)
- [MuxRepository](#mux-repository)
- [AsyncMedia](#media-downloader)
- [Experimental features](#experimental)
- [Building and linking](#building)
- [Change history](#changes)
- [Authors](#authors)


<a name="intro"></a>
## Introduction

The Swift AsyncMux utility suite provides a caching/multiplexing layer for network objects, based on Swift's Structured Concurrency (`async/await`). AsyncMux is an evolution of an older, callback-based library available [here](https://github.com/crontab/Multiplexer).

Here are the scenarios that are covered by the Multiplexer utilities:

**Scenario 1:** execute an async block, typically a network call, and return the result to one or more callers. Various parts of your app may be requesting e.g. the user's profile simultaneously at program startup; you want to make sure the network request is performed only once, then the result is returned to all parts of the app that requested the object. We call it **multiplexing**.

Additionally, provide caching of the results in memory for a certain period of time. Subsequent calls to a multiplexer may return the cached result unless some time-to-live (TTL) elapses, in which case a new network call is made transparently.

**Scenario 2:** if your app is launched while there's no network connection, allow the app to show at least *some* content. This is achieved by caching the network objects on disk so that they can survive app reboots, and by having multiplexers automatically return the cached results regardless of their TTL in case there was a connection error.

Provide "soft" and "hard" refresh functions for each multiplexer.

**Scenario 3:** provide file downloading, multiplexing and disk caching for immutable objects, such as media files and documents.


<a name="multiplexer"></a>
## Multiplexer<T>

`Multiplexer<T>` is an asynchronous caching facility for client apps. Each multiplxer instance can manage retrieval, multiplexing and caching of one object of type `T: Codable & Sendable`, therefore it is best to define each multiplexer instance in your app as a singleton. Also note that `Multiplexer` itself is an actor, therefore all its public methods are asynchronous.

For each multiplexer singleton you define a block that implements asynchronous retrieval of an object, which may be e.g. a network request to your backend system.

A multiplexer singleton guarantees that there will only be one fetch/retrieval operation made, and that subsequently a memory-cached object will be returned to the callers of its `request()` method , unless the cached object expires according to the `defaultTTL` setting (currently set to 30 minutes). Additionally, Multiplexer can store the object on disk - see [`MuxRepository`](#mux-repository) and also the discussion on `request()` below.

Suppose you have a `UserProfile` structure and a method for retrieving the current user's profile object from the backend, whose signature looks like this:

```swift
class Backend {
    static func fetchMyProfile() async throws -> UserProfile {
        // ...
    }
}
```

Then an instantiation of a multiplexer singleton will look like:

```swift
let myProfile = Multiplexer<UserProfile>(onFetch: {
    try await Backend.fetchMyProfile()
})
```

Or even shorter:

```swift
let myProfile = Multiplexer(onFetch: Backend.fetchMyProfile)
```

Now you can use `myProfile` to fetch the profile object by calling the `request()` method like so:

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

By default, `Multiplexer<T>` can store objects as JSON files in the local cache directory. To enable this feature, provide a unique `cacheKey` in the multiplexer's constructor:
    
```swift
let myProfile = Multiplexer<UserProfile>(cacheKey: "MyProfile") {
    try await Backend.fetchMyProfile()
}
```

The objects stored on disk can be reused by the multiplexer even after TTL expires if your `onFetch` fails due to a connectivity problem. You can additionally tell the multiplexer to ignore the error and fetch the cached object by throwing a `SilenceableError` in your `onFetch` method.

The disk storage method is currently hardcoded but will be possible to override in the future releases of the library.

At run time, you can invalidate the cached object using one of the following methods:

- "Soft refresh": chain the `refresh()` method with a call to `request()`: the multiplexer will attempt to fetch the object again, but will not discard the existing cached objects in memory or on disk. In case of a silenceable error (i.e. connectivity issue) the older cached object will be used again as a result.
- "Hard refresh": call `clear()` to discard both memory and disk caches for a given object. The next call to `request()` will attempt to fetch the object and will fail in case of an error.

More detailed descriptions on each method can be found in the source file [Multiplexer.swift](AsyncMux/Sources/Multiplexer.swift).


<a name="multiplexer-map"></a>
## MultiplexerMap<K, T>

`MultiplexerMap<K, T>` is similar to `Multiplexer<T>` in many ways except it maintains a dictionary of objects of the same type. One example would be e.g. user profile objects in your social app. Internally, a multiplexer map is a dictionary of multiplexers whose code is executed by the same actor.

The `K` generic paramter should conform to `LosslessStringConvertible & Hashable & Sendable`. The string convertibility requirement is because it simplifies the disk cacher's job of storing objects.

The examples given for the Multiplexer above will look as follows. Firstly, suppose you have a method for retrieving a user profile by a user ID:

```swift
class Backend {
    static func fetchUserProfile(id: String) async throws -> UserProfile {
        // ...
    }
}
```

Further, the MultiplexerMap singleton can be defined as follows:

```swift
let userProfiles = MultiplexerMap(onFetch: Backend.fetchUserProfile)
```

And used in the app like so:

```swift
try {
    let profile = try await userProfiles.request(key: "user_8cJOiRXbugFccrUhmCX2")
}
catch {
    print("Coudn't retrieve user profile:", error)
}
```

Like `Multiplexer`, `MultiplexerMap` defines its own methods `refresh()`, `clear()` and `save()`. Additionally for `refresh()` and `clear()` there are versions of these methods that take the object key as a parameter.

Internally `MultiplexerMap` maintains a map of `Multiplexer` objects, meaning that fetching and caching of each object by its ID is done independently.

More detailed descriptions on each method can be found in the source file [MultiplexerMap.swift](AsyncMux/Sources/MultiplexerMap.swift).

<a name="mux-repository"></a>
## MuxRepository

`MuxRepository` is a collection of asynchronous static functions that can be used for centralized operations such as `clearAll()` and `saveAll()` on all registered multiplexer instances in your app. You should register each instance by providing a unique `cacheKey` when creating multiplexer instances.

By default, the `Multiplexer` and `MultiplexerMap` interfaces don't store objects on disk. If you want to keep the objects to ensure they survive app reboots, make sure you call `MuxRepository.saveAll()` when the app is sent to background, [like shown in the Demo app](AsyncMuxDemo/Sources/AsyncMuxDemoApp.swift).

`MuxRepository.clearMemory()` discards all objects stored in memory. Useful when handling memory warnings coming from the OS (see the demo app for sample usage).

`MuxRepository.clearAll()` discards all memory and disk objects. This is useful when e.g. the user signs out of your system and you need to make sure no traces are left of data related to a given user in memory or disk.


<a name="media-downloader"></a>
## AsyncMedia

`AsyncMedia` is a fully static interface that provides a downloading, multiplexing and caching facility for arbitrary large files that are considered immutable.

Like with other multiplexers, `AsyncMedia` ensures that for each remote URL only one download process is active regrdless of the number of times the `request(url:)` was called simultaneously.

The download process is based on streaming, which means memory used by each download process is fixed and doesn't depend on the file size.

Each file you request using `AsyncMedia.request(url:)` is downloaded and stored locally in the app's cache directory; the local file URL is then returned asynchronously. Subsequent calls to `request(url:)` for the same URL will return the local file URL immediately.

Use `cachedValue(url:)` to get the local file URL of a cached object, if available.

Note that the remote files are assumed to be immutable, and therefore no time-to-live is maintained, i.e. it is assumed that the file can be stored in the local cache indefinitely. Note also that the OS can wipe the app's cache directory if it needs to free space, which normally should happen when the app is not running. Additionally, you can purge the media cache directory by calling `AsyncMedia.clear()`.

The demo app includes a complete package for in-memory LRU caching of images backed by `AsyncMedia`, as well as the [`RemoteImage` UI component](AsyncMuxDemo/Sources/RemoteImage) that uses both. Effectively `RemoteImage` is an alternative to SwiftUI's `AsyncImage` that in addition can cache immutable images locally.


<a name="experimental"></a>
## Experimental features

**Zip**: `Zip<T>` allows to combine two or more parallel asynchronous actions into one and receive the results from all of them at once, when they become available. The result of the execution is returned as an array of T. For example usage see function `reload()` in [the demo app's `ContentView`](AsyncMuxDemo/Sources/ContentView.swift).

Additionally, a family of global functions `zip(...)` provide shortcuts for a fixed number of async calls (up to 5).

See: [`Zip.swift`](AsyncMux/Sources/Zip.swift). 

**MultiRequester**: If your backend supports multiple-ID requests (e.g.`/profiles/[id1,id2]`), then MultiRequester can be used in tandem with an existing MultiplexerMap object to combine single and multi-requests into the same caching infrastructure. Multi-ID requests made via MultiRequester's `request(...)` method can update the map linked to it and also reuse the cached values stored by the map. Thus, objects will be cached locally regardless of whether they were requested via singular endpoints or multi-ID ones; and on the other hand, multi-ID requests can save bandwidth by reusing the objects already cached and requesting fewer ID's (or even none) from the backend.

See: [`MultiRequester.swift`](AsyncMux/Sources/MultiRequester.swift) 

*NOTE: these experimental features are not guararanteed to be compatible in the future releases, or that they won't be removed altogether.*

<a name="building"></a>
## Building and linking

You can either use the SPM package definition provided, or alternatively clone this repo and use it as a git submodule in your project.

If you want to try the demo, launch the `AsyncMux.xcworkspace` file. Weather API used in the demo app: [Open Meteo](https://open-meteo.com/en/docs)

The AsyncMux framework doesn't have any 3rd party dependencies.

Enjoy your coding!


<a name="changes"></a>
## Change log
### v2.2

- Bumped both the demo app and framework to iOS 17.
- `store(value:)` and `storedValue` methods for both `Multiplexer` and `MultiplexerMap` are now public.
- Experimental: added a `refresh()` method to `MultiRequester`; it forwards the refresh request to the map tied to it.
- Demo app: fixed an issue in the `RemoteImage` implementation; it now uses an `@Observable` view model.
- Internal: removed the `refreshFlag` property in multiplexers, it complicated the logic and introduced problems.

### v2.1

- Added the experimental `MultiRequest` interface. The idea comes from the previous incarnation of the library where it worked pretty well for client apps.

### v2.0

- Upgraded the project to Swift 6; fixed all concurrency issues
- Removed `register()` and `unregister()` methods from `MuxRepository`; registration is now automatic as long as `cacheKey` is provided when creating an instance of a multiplexer.
- `MuxRepository` and `AsyncMedia` are now static interfaces with async methods, i.e. no `shared` instance anymore.

<a name="authors"></a>
## Authors

AsyncMux is developed by [Hovik Melikyan](https://github.com/crontab).
