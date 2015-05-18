# Atom PHP Debugging Package

Debug PHP code using the [XDebug PHP Extension](http://xdebug.org/).

# Features
- Add Breakpoints
- Step through debugging (Over, In, Out)
- Stack and Context views
- Add Watchpoints to inspect current values of variables

This is currently an alpha release, and still in active development.

![](https://raw.githubusercontent.com/gwomacks/php-debug/master/screenshot.png)

# Settings

Put the following in your config.cson
```cson
"php-debug":
  {
    ServerPort: 9000
    PathMaps: [
      {
        local: "C:\\base\\path\\on\\local\\system"
        remote: "/base/path/on/remote/system"
      },
      {
        local: "C:\\another\\path\\map"
        remote: "/home/yay/"
      }
    ]
  }
  ```
