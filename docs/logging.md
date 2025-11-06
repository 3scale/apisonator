# Logging Architecture in Apisonator

## Overview

Apisonator implements a multi-logger architecture with three specialized loggers, each serving distinct purposes in the system. This separation provides granular control over different aspects of application monitoring and debugging.

## The Three Logger Types

### 1. Backend Logger (`Backend.logger`)

**Purpose:** General application-wide logging unrelated to HTTP requests

**Location:** `lib/3scale/backend/logging.rb:50`

**Configuration:**
* Output: `CONFIG_LOG_PATH` (defaults to `/dev/stdout`)
* Rotation: 10 log files
* Format: Standard Ruby Logger format

**Key Features:**
* Custom `notify` method for exception logging
* Integrates with external services (Bugsnag) for exception tracking
* Used by Listener, Worker, Cron, and rake tasks

**Usage Pattern:**
```ruby
include Logging  # Provides logger method
logger.info("General application message")
logger.notify("Exception occurred", exception)
```

**Rationale:** Provides centralized application-level logging separate from request/job-specific concerns. The `notify` method enables dual logging (file + external service) for critical exceptions.

---

### 2. Worker Logger (`Worker.logger`)

**Purpose:** Background job processing logs with performance metrics

**Location:** `lib/3scale/backend/logging/worker.rb`

**Configuration:**
* Output: `CONFIG_WORKERS_LOG_FILE` (defaults to `/dev/stdout`)
* Format: `CONFIG_WORKERS_LOGGER_FORMATTER` (text or json)

**Available Formats:**

| Format | Output Example | Use Case |
|--------|----------------|----------|
| PlainText | `INFO 12345 [2025-01-06] Job completed in 0.5s` | Human-readable logs |
| JSON | `{"severity":"INFO","pid":12345,"timestamp":"2025-01-06T10:30:00Z","job_class":"ReportJob","runtime":0.5,"memoizer_hits":150}` | Structured logging for log aggregation systems |

**Logged Metrics:**
* Job execution time (`runtime`)
* Total time including queue wait (`run_plus_queued_time`)
* Memoizer statistics (`size`, `count`, `hits`)
* Job class and metadata

**Usage Pattern:**
```ruby
Worker.logger.info("Job processing: #{job_class} #{runtime}s")
Worker.logger.error("Worker received nil job from queue")
```

**Rationale:** Dedicated logger for job processing enables performance monitoring and troubleshooting without polluting general application logs. JSON format supports integration with log aggregation platforms (ELK, Splunk).

---

### 3. Request Logger (Middleware-based)

**Purpose:** HTTP request/response tracking for the Listener API

**Location:** `lib/3scale/backend/logging/middleware.rb`

**Implementation:** Rack middleware that intercepts all HTTP requests

**Configuration:**
* Format: `CONFIG_REQUEST_LOGGERS` (comma-separated: `text`, `json`, or `text,json`)
* Default: `text`
* Supports dual logging (both formats simultaneously)

**Available Writers:**

| Writer | Format | Example |
|--------|--------|---------|
| TextWriter | Apache Combined Log + Extensions | `127.0.0.1 - - [06/Jan/2025:10:30:00] "GET /transactions/authrep.xml HTTP/1.1" 200 150 0.025s` |
| JsonWriter | Structured JSON | `{"forwarded_for":"127.0.0.1","method":"GET","path":"/transactions/authrep.xml","status":200,"response_time":0.025,"request_id":"abc123"}` |

**Logged Data:**
* **Request:** forwarded_for, method, path, query_string, HTTP version
* **Response:** status code, content length, response time
* **Extensions:** request_id, 3scale-specific options, memoizer statistics

**Automatic Operation:** No manual logging required; middleware captures all requests

**Rationale:** Dedicated HTTP logging separates web traffic analysis from application logic. Middleware approach ensures consistent logging across all endpoints without code duplication. Support for multiple formats enables both human debugging and automated analysis.

---

## Configuration Summary

### Environment Variables

| Variable | Logger | Purpose | Default |
|----------|--------|---------|---------|
| `CONFIG_LOG_PATH` | Backend | General app log file path | `backend_logger.log` or STDOUT |
| `CONFIG_WORKERS_LOG_FILE` | Worker | Worker job log file path | `/dev/stdout` |
| `CONFIG_WORKERS_LOGGER_FORMATTER` | Worker | Log format (text/json) | `text` |
| `CONFIG_REQUEST_LOGGERS` | Request | HTTP log formats | `text` |

### Configuration Files

* **Main:** `lib/3scale/backend/configuration.rb:38-39`
* **Production:** `openshift/3scale_backend.conf:68-70`

---

## Web Server Logging Integration

### Why Web Server Logging is Disabled

**Puma Configuration** (`config/puma.rb:61`):
```ruby
quiet  # Disables Puma's request logging
```

**Sinatra Configuration** (`lib/3scale/backend/listener.rb:9`):
```ruby
disable :logging  # Turns off Sinatra's default logging
```

**Rationale:**
1. **Avoid duplication:** Web servers (Puma/Falcon) and frameworks (Sinatra) have basic logging that would duplicate Apisonator's richer middleware logs
2. **Enhanced data:** Apisonator's middleware captures 3scale-specific data (memoizer stats, extensions) not available in standard web server logs
3. **Consistent format:** Single source of truth for request logging ensures uniform format across all deployments
4. **Performance:** Eliminates overhead of redundant logging operations

---

## Architecture Flow

```
┌─────────────────────────────────┐
│ Web Server (Puma/Falcon)        │
│ [logging disabled]               │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Rack Middleware Stack           │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Logging::Middleware             │
│ [intercepts all requests]       │
├─────────────┬───────────────────┤
│ ├─→ TextWriter → STDOUT/file   │
│ └─→ JsonWriter → STDOUT/file   │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Listener/Internal API           │
│ [includes Backend.logger]       │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Backend.logger                  │
│ [app logging + Bugsnag]         │
└─────────────────────────────────┘

              │
              ▼
┌─────────────────────────────────┐
│ Background Jobs → Resque Queue  │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Worker Process                  │
│ [Worker.logger]                 │
└─────────────────────────────────┘
```

---

## Key Differences Between Loggers

| Aspect | Backend Logger | Worker Logger | Request Logger |
|--------|----------------|---------------|----------------|
| **Scope** | Application-wide | Job-specific | Request-specific |
| **Trigger** | Manual (code calls) | Automatic (per job) | Automatic (per request) |
| **Format** | Standard Ruby Logger | Text or JSON | Text or JSON or Both |
| **Output** | File or STDOUT | File or STDOUT | STDOUT/STDERR |
| **Primary Data** | Exceptions, warnings, info | Job metrics, performance | HTTP request/response |
| **External Integration** | Bugsnag | None | None |
| **Performance Focus** | No | Yes (runtime, queue time) | Yes (response time) |
| **Use Case** | Debugging, exception tracking | Job monitoring, performance analysis | Traffic analysis, API debugging |

---

## External Logging Integration

**Location:** `lib/3scale/backend/logging/external/`

**Implementations:**
* **Default:** No-op implementation
* **Bugsnag:** Exception tracking service
  * Environment variables: `CONFIG_HOPTOAD_SERVICE`, `CONFIG_HOPTOAD_API_KEY`
  * Integration points:
    * Rack middleware (`setup_rack`)
    * Resque worker jobs (`setup_worker`)
    * Backend logger `notify` method

**Rationale:** Centralized exception tracking across all components (Listener, Worker) enables proactive monitoring and faster incident response.

---

## Design Rationale Summary

1. **Separation of Concerns:** Each logger handles a specific domain (application, jobs, requests) preventing log pollution and enabling targeted analysis
2. **Flexible Output:** Support for both text and JSON formats accommodates different environments (development vs production, human debugging vs automated analysis)
3. **Performance Monitoring:** Dedicated metrics (job runtime, response time, memoizer stats) built into logging infrastructure
4. **Cloud-Native:** Default STDOUT output supports container environments and log aggregation platforms
5. **Minimal Overhead:** Web server logging disabled to avoid duplication and reduce I/O operations
6. **External Integration:** Bugsnag integration provides centralized exception tracking across distributed components
7. **Configuration Flexibility:** Environment variables enable runtime configuration without code changes

This architecture supports both development debugging (readable text logs) and production monitoring (structured JSON logs with metrics) while maintaining clean separation between different logging concerns.