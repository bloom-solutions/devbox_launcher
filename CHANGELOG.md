# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2021-12-20
### Changed
- Update compatibility with mutagen 0.12.0. Drops support for previous versions

## [0.7.1] - 2021-10-14
### Fixed
- Explicitly require fileutils for Ruby 3.0 compatibility

## [0.7.0] - 2021-09-23
### Added
- Add ability to set a box's user and identity_file

## [0.6.1] - 2021-09-22
### Fixed
- Do not blow up if mutagen is not configured

## [0.6.0] - 2021-09-21
### Changed
- Ability to configure multiple boxes under one account

## [0.5.2] - 2021-05-31
### Added
- Ignore VCS as recommended by mutagen

### Fixed
- Retry on `Errno::ECONNREFUSED`

## [0.5.1] - 2021-04-08
### Fixed
- Use configured `zone` for describe as well

## [0.5.0] - 2021-04-06
### Added
- Ability to specify `zone` in config

## [0.4.0]
### Added
- Sync mutagen with two-way-resolved

## [0.3.5]
### Fixed
- When running commands, also rescue from whitelist of exceptions, and retry

## [0.3.4]
### Added
- Rescue from `Errno::ECONNREFUSED` and retry

## [0.3.3]
### Fixed
- Support launching multiple boxes at the same time

## [0.3.2]
### Fixed
- Fix: add missing file

## [0.3.1]
### Fixed
- Recover when the devbox is in a shutdown cycle

## [0.3.0]
### Changed
- Label sessions with devbox
- On linux, mutagen relies on watchman to detect changes

### Fixed
- In Linux, mutagen no longer burns CPU every 10 seconds

## [0.2.0]
### Added
- Initial release
