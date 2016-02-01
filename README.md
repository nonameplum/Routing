# Routing

[![Platform support](https://img.shields.io/badge/platform-ios-lightgrey.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md) [![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md)

# Table of Contents

- [About Routing](#about-routing)
- [Installation](#installation)
- [Testing](#testing)
- [Example](#example)
- [Collaboration](#collaboration)

# About Routing

Routing allows for mapping string patterns to an associated closure.

To map a route with a string pattern.

```swift
let router = Routing()
router.map("/route") { (parameters, completed) in
	...
	completed() // Must call completed or the router will halt!
}
```

To proxy a route with a string pattern.

```swift
router.proxy("/route") { (var route, var parameters, next) in
	...
	next(route, parameters) // Must call next or the router will halt!
}
```

To open a URL.

```swift
router.open(NSURL(string: "host://route/")!) // Will return true or false if there is an associated route
```

# Installation

# Testing

# Example

# Collaboration

