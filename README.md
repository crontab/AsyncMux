# AsyncMux
### Asnychronous multiplexer utilities with caching for Swift

*This is an evolution of the older [Multiplexer library](https://github.com/crontab/Multiplexer), now refactored under Swift's structured concurrency.*

#### Table of contents

- [Introduction](#intro)

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






Weather API used in the demo app: [Open Meteo](https://open-meteo.com/en/docs)
