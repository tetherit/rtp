# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- `rake` or `rake test` - Run RSpec tests (default task)
- `bundle exec rspec` - Run all RSpec tests
- `bundle exec rspec spec/rtp/receiver_spec.rb` - Run specific test file
- `bundle exec cucumber` - Run Cucumber acceptance tests

### Code Quality
- `bundle exec rubocop` - Run RuboCop linter (configured via Gemfile)

### Documentation
- `rake yard` - Generate YARD documentation with private/protected methods

### Gem Management
- `bundle install` - Install dependencies
- `rake build` - Build the gem
- `rake release` - Release the gem to RubyGems

## Architecture Overview

This is a pure Ruby RTP (Real-Time Transport Protocol) library focused on receiving and parsing RTP streams.

### Core Components

**RTP::Receiver** (`lib/rtp/receiver.rb`) - The main component for receiving RTP data:
- Supports UDP/TCP transport protocols
- Handles both unicast and multicast reception
- Thread-based architecture with separate listener and packet writer threads
- Can stream to file or yield packets to a block for real-time processing
- Uses Queue for thread-safe packet handling between listener and writer

**RTP::Packet** (`lib/rtp/packet.rb`) - RTP packet parser using BinData:
- Parses standard RTP headers (version, sequence number, timestamp, SSRC, etc.)
- Supports extension headers
- Extracts RTP payload for further processing
- Binary data parsing with proper endianness handling

**RTP::Error** (`lib/rtp/error.rb`) - Custom exception class for RTP-specific errors

### Key Design Patterns

- **Thread-based concurrency**: Separate threads for packet listening and writing to prevent I/O blocking
- **Producer-consumer pattern**: Uses Queue for thread-safe communication between listener and packet writer
- **Options hash initialization**: Flexible configuration through hash parameters
- **Block-based packet inspection**: Optional block yielding for real-time packet analysis
- **Automatic resource cleanup**: Uses at_exit hooks to ensure capture files are properly closed

### Dependencies

- `bindata` - Binary data parsing for RTP packets
- `semantic_logger` - Structured logging throughout the library
- Standard Ruby socket libraries for network communication

### Testing Structure

- **RSpec** tests in `spec/` directory for unit testing
- **Cucumber** tests in `features/` for acceptance testing
- **SimpleCov** for test coverage reporting
- Test helper configures coverage reporting and load paths

### Network Handling

- Supports both IPv4 unicast and multicast
- Multicast detection based on IP address range (224.x.x.x - 239.x.x.x)
- Socket configuration with timestamps and timeout options
- Non-blocking socket operations to prevent deadlocks