# dydump

A MobileSubstrate tweak for iOS that provides runtime class dumping capabilities with a user interface overlay.

## Overview

dydump is an iOS tweak that integrates with the ClassDumpRuntime library to provide runtime class inspection and dumping functionality. The tweak presents a UI overlay that allows users to analyze and dump Objective-C classes from running applications.

### Demo

https://github.com/raulsaeed/dydump/blob/85619c5b7a724baaa2e5b5cb7835325a7461faa0/screenshots

### Features

- Runtime class dumping using ClassDumpRuntime library
- User-friendly UI overlay for easy access
- Remote logging capabilities
- Automatic injection into target applications

## Dependencies

- **ClassDumpRuntime**: A Swift library for runtime class dumping and reflection
- **MobileSubstrate**: iOS tweak injection framework
- **Theos**: Build system for iOS tweaks

## Build Instructions

### Prerequisites

1. Install Theos build system
2. Set up your iOS development environment
3. Ensure you have the required signing certificates

### Setup

1. Clone the ClassDumpRuntime repository:
   ```bash
   git clone https://github.com/leptos-null/ClassDumpRuntime.git
   ```

2. Build the project:
   ```bash
   make package
   ```

### Build Requirements

- **Target**: iPhone with iOS 14.5+
- **Architecture**: ARM64 (iphoneos-arm)
- **Compiler**: Clang with ARC support

## Configuration

The tweak is configured to:
- Remote logging: 192.168.100.6:5021 (configurable in Tweak.x)
- Device IP: 192.168.100.35 (configurable in Makefile)

## Installation

1. Build the package using `make package`
2. inject the generated `.deb` or `.dylib` using TrollFools or eSign or any other signer   
3. The Tweak's UI will appear 5s after app lauch 

## Usage

Once installed, the tweak will:
1. Automatically present a UI overlay when the target app launches
2. Provide class dumping functionality through the interface
3. Log activities to the configured remote logging server

## File Structure

- `Tweak.x` - Main tweak implementation with MobileSubstrate hooks
- `DYDumpHeaderDumper.*` - Core dumping functionality
- `DYDumpHeaderDumperUI.*` - User interface components
- `IOSLogger.*` - Remote logging implementation
- `ClassDumpRuntime/` - Third-party class dumping library
- `Makefile` - Build configuration

## License

This project integrates with ClassDumpRuntime. Please refer to the respective licenses of the dependencies used.