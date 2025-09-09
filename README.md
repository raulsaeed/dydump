# DYDump - ClassDumpRuntime UI Wrapper

DYDump is a user-friendly iOS interface for [ClassDumpRuntime](https://github.com/leptos-null/ClassDumpRuntime), providing an intuitive way to dump Objective-C class headers from any iOS application.

## Features

- **Pattern-Based Filtering**: Filter classes using wildcards (e.g., `UIKit*`, `*View*`)
- **Customizable Options**: Configure header generation with multiple options
- **Concurrent Processing**: High-performance multi-threaded dumping

## Screenshots

The tool provides a clean, scrollable interface with:
- Pattern input field with keyboard toolbar
- Live class count analysis
- Configurable generation options
- Progress tracking with cancel capability

## Generation Options

### Available Options:
- **Add Symbol Image Comments**: Include image path comments in headers
- **Strip Synthesized Properties**: Remove auto-generated property implementations
- **Strip Overrides**: Remove method overrides from superclasses
- **Strip Protocol Conformance**: Remove protocol conformance declarations
- **Strip Duplicates**: Remove duplicate method declarations

### Default Settings:
- ✅ Strip Overrides (ON)
- ✅ Strip Protocol Conformance (ON)
- ✅ Strip Duplicates (ON)
- ❌ Add Symbol Image Comments (OFF)
- ❌ Strip Synthesized Properties (OFF)

## Usage

### Programmatic Usage

```objc
// Present the UI from any view controller
[DYDumpHeaderDumperUI presentFromViewController:someViewController];

// Direct dumping (all classes)
[DYDumpHeaderDumper dumpAllClassHeaders];

// Targeted dumping with options
NSDictionary *options = @{
    @"stripOverrides": @YES,
    @"stripDuplicates": @YES,
    // ... other options
};
[DYDumpHeaderDumper dumpClassHeaders:classArray withOptions:options];
```

### UI Workflow

1. **Enter Pattern**: Type a class name pattern (optional)
   - Examples: `UIKit*`, `*View*`, `NS*`, or leave empty for all classes
2. **Analyze**: Tap "Analyze Classes" to see how many classes match
3. **Configure**: Adjust generation options as needed
4. **Dump**: Tap "Dump Headers" to start the process
5. **Monitor**: Watch real-time progress with cancel option
6. **Access**: Find headers in Files app under `Documents/headers/`

## Installation & Compilation

### Prerequisites

- **Theos**: iOS development environment
- **ClassDumpRuntime**: Core dumping library
- **iOS Device**: Jailbroken device for testing

### Build Instructions

1. **Clone the repository**:
```bash
git clone <repository-url>
cd dydump
```

2. **Install dependencies**:
   - Ensure ClassDumpRuntime is installed on your device
   - Make sure IOSLogger is available in your project

3. **Configure Makefile**:
```makefile
# Example Makefile configuration
TARGET := iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DYDump

DYDump_FILES = Tweak.x DYDumpHeaderDumper.m DYDumpHeaderDumperUI.m
DYDump_FRAMEWORKS = UIKit Foundation
DYDump_PRIVATE_FRAMEWORKS = 
DYDump_LIBRARIES = 

include $(THEOS_MAKE_PATH)/tweak.mk
```

4. **Build the project**:
```bash
make
```

5. **Install on device**:
```bash
make package install
```

6. **Respring**:
```bash
killall -9 SpringBoard
```

## File Structure

```
dydump/
├── DYDumpHeaderDumper.h          # Core dumper interface
├── DYDumpHeaderDumper.m          # Core dumper implementation
├── DYDumpHeaderDumperUI.h        # UI interface
├── DYDumpHeaderDumperUI.m        # UI implementation
├── IOSLogger.h                   # Logging utility
├── Tweak.x                       # Tweak integration
├── Makefile                      # Build configuration
└── README.md                     # This file
```

## Technical Details

### Performance Features
- **Concurrent Processing**: Uses GCD for parallel class processing
- **Thread-Safe Counters**: Atomic operations for progress tracking
- **Memory Management**: Auto-release pools in worker threads
- **Progress Batching**: Efficient UI updates without overwhelming main thread

### Output Location
Headers are saved to:
```
Documents/headers/ClassName.h
```

This location is accessible through:
- Files app on iOS
- iTunes file sharing
- Third-party file managers

### Safety Features
- **Class Safety Check**: Validates classes before processing
- **Error Handling**: Graceful handling of write errors
- **Cancellation Support**: Clean cancellation with optional file cleanup
- **State Management**: Proper UI state during all operations

## Credits

**DYDump** - ClassDumpRuntime UI Wrapper
- **Raul** ([@raulsaeed](https://github.com/raulsaeed)) - UI Wrapper Developer
- **leptos** ([@leptos-null](https://github.com/leptos-null)) - ClassDumpRuntime Developer

ClassDumpRuntime is the core library that powers this tool.

## License

This project is provided as-is for educational and research purposes. Please respect the intellectual property of applications you analyze.

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check ClassDumpRuntime documentation for core functionality
- Ensure your device has proper ClassDumpRuntime installation

---

**Note**: This tool requires a jailbroken iOS device and is intended for legitimate security research and educational purposes.