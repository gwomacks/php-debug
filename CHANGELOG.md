## 0.3.5
* Fix issue where turning off multiple sessions wasn't working
* Fix several issues where pathmaps weren't functioning correctly
* Add ability to ignore pathmap files by setting the local path to "?"
* Misc bug Fixes
* Add configuration to have pathmap searching ignore certain directories

## 0.3.4
* Even more parser fixes
* Feature: Ability to ignore paths/files via pathmap setting where the local side is set to "!"
* Feature: New configuration option "Allow for multiple debug sessions at once" to disable/enable multi session support
* Feature: New configuration option "Automatically scan projects in Atom to try and find path maps"
* Feature: New configuration option "Continue to listen for debug sessions even if the debugger windows are all closed"
* Breakpoints now print info to the PHP-Debug console
* Fix missing code for atom commands
* Update to require version 1.0.3 of atom-debug-ui

## 0.3.3
* Additional parser fixes
* Additional debugging functionality to the parser

## 0.3.2
* Fix typo in fix for 0.3.1 parser
* Fix messages in config [thanks PHLAK]

## 0.3.1
* Fix multiple issues with the parser
* Fix typo for notifications
* Fix check for notification installation prompt

## 0.3.0
* Almost a complete rewrite
* Utilize atom-debug-ui package
* UTF-8 Support for member names and data
* Support for multiple debug sessions/instances
* New pathmaps functionality, old style is replaced
* Better status messages
* More options for UI tweeks

* Via atom-debug-ui: A huge number of UI cleanups
* Via atom-debug-ui: Support for Atom dock functionality
* Via atom-debug-ui: Floating/Overlay Actionbar
* Via atom-debug-ui: Better access to settings for breakpoints
* Via atom-debug-ui: Better highlighting for variables
* Via atom-debug-ui: Better status messages
* Via atom-debug-ui: Better console support

## 0.2.6
* Fix bug(s) with new socket binding code, should fix Atom freezes
* Fix for scrollbar styling [thanks pictus]
* Add console history/log [thanks StAmourD and cgalvarez]
* Add theming to panel php data [thanks StAmourD and cgalvarez]
* Add better display/styling of object/arrays [thanks StAmourD and cgalvarez]
* Sorting for objects/arrays [thanks StAmourD and cgalvarez]
* Bug fixes [with thanks StAmourD and cgalvarez]
* Documentation fix for ServerAddress [thanks ptrm04]

## 0.2.5
* Implemented host specific listening [thanks lfarkas]
* Add support for filtering file paths during debugging [thanks StAmourD]
* Add support for activating the Atom window after a breakpoint triggers [thanks StAmourD]
* Make adjustments to readme [thanks surfer190]
* Add check on xdebug server for file to match breakpoints [thanks QwertyZW]
* Adjustments to action bar button styling [thanks CraigGardener]
* Many bug fixes

## 0.2.4
* Allow main panel to be docked to the side or the bottom
* Add an interactive console
* Allow different views to be closed and restored
* Many bug fixes

## 0.2.3
* Change the way that scrolling works within the panel
* Add ability to auto expand locals in the context
* Support for resource data types from PHP
* Classnames for objects in the context view
* Allow port to be adjusted after php-debug has already been enabled once
* Bug fixes

## 0.2.2
* Add ability to toggle breakpoints from editor gutter
 * This can be enabled and configured via the settings
* Attempt to resolve encoding issue by switching socket parsing to ASCII instead of UTF8
* Fix paths bug
* Better handling of socket in use errors
* Bug fixes

## 0.2.1
* Bug fixes

## 0.2.0
* Bug fixes
* Move unified panel into bottom panel
* Change remote debugging configuration so it works

## 0.1.4
* Bug fixes
* Code cleanups
* Data handling improvements (protocol)
* Context preservation between break refreshes
* UX improvements
* Improved watchpoint handling

## 0.1.3
* Bug fixes
* UX Bug fixes ( breakpoints)
* Improved exception handling
* Stackframe selection

## 0.1.2
* Add settings for selection Exceptions
* Add custom Exceptions
* Enable keybinding on debuggin panes
* UX improvements

## 0.1.1
* Optimizations
* Bug fixes
* Default changes for max depth / max children

## 0.1.0
* UX improvements
* Bug fixes
* Additional configuration for Max Depth, Max children, Max data
* Improved breakpoints

## 0.0.13
* Bug fixes (protocol)
* UX improvements

## 0.0.12
* Bug fixes (buffer handling)

## 0.0.11
* Additional type support
* UX improvements
* Bug fixes

## 0.0.10
## 0.0.9
* Project rename

## 0.0.8
* Breakpoint bug fixes
* Fixes for stopping
* Bug fixes

## 0.0.7
* Formatting Adjustments
* Bug fixes for max osx

## 0.0.6
* Bug fixes (stepping,boolean values)

## 0.0.5
* Readme Adjustments
* Path conversion fixes
* Better support for stopping

## 0.0.4
* Improve watchpoints

## 0.0.3
* Bug fixes for contexts

## 0.0.2
* Bug fixes for xmljs

## 0.0.1 - First Release
* Initial Release
