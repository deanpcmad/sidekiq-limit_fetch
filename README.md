## Description

*This project has been taken over by [@deanpcmad](https://github.com/deanpcmad). Original code by [@brainopia](https://github.com/brainopia).*

Sidekiq strategy to support a granular queue control – limiting, pausing, blocking, querying.

[![CI](https://github.com/deanpcmad/sidekiq-limit_fetch/actions/workflows/ci.yml/badge.svg)](https://github.com/deanpcmad/sidekiq-limit_fetch/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/sidekiq-limit_fetch.svg)](http://badge.fury.io/rb/sidekiq-limit_fetch)

### Installation

Add this line to your application's Gemfile:

```
gem 'sidekiq-limit_fetch'
```

Then `bundle install`.

### Limitations

**Important note:** At this moment, `sidekiq-limit_fetch` is incompatible with
- sidekiq pro's `reliable_fetch`
- `sidekiq-rate-limiter`
- any other plugin that rewrites fetch strategy of sidekiq.

### Usage

If you are using this with Rails, you don't need to require it as it's done automatically.

To use this Gem in other Ruby projects, just add `require 'sidekiq-limit_fetch'`.

### Limits

Specify limits which you want to place on queues inside sidekiq.yml:

```yaml
:limits:
  queue_name1: 5
  queue_name2: 10
```

Or set it dynamically in your code:
```ruby
Sidekiq::Queue['queue_name1'].limit = 5
Sidekiq::Queue['queue_name2'].limit = 10
```

In these examples, tasks for the `queue_name1` will be run by at most 5
workers at the same time and the `queue_name2` will have no more than 10
workers simultaneously.

Ability to set limits dynamically allows you to resize worker
distribution among queues any time you want.

### Limits per process

If you use multiple sidekiq processes then you can specify limits per process:

```yaml
:process_limits:
  queue_name: 2
```

Or set it in your code:

```ruby
Sidekiq::Queue['queue_name'].process_limit = 2
```

### Busy workers by queue

You can see how many workers currently handling a queue:

```ruby
Sidekiq::Queue['name'].busy # number of busy workers
```

### Pauses

You can also pause your queues temporarily. Upon continuing their limits
will be preserved.

```ruby
Sidekiq::Queue['name'].pause # prevents workers from running tasks from this queue
Sidekiq::Queue['name'].paused? # => true
Sidekiq::Queue['name'].unpause # allows workers to use the queue
Sidekiq::Queue['name'].pause_for_ms(1000) # will pause for a second
```

### Blocking queue mode

If you use strict queue ordering (it will be used if you don't specify queue weights)
then you can set blocking status for queues. It means if a blocking
queue task is executing then no new task from lesser priority queues will
be ran. Eg,

```yaml
:queues:
  - a
  - b
  - c
:blocking:
  - b
```

In this case when a task for `b` queue is ran no new task from `c` queue
will be started.

You can also enable and disable blocking mode for queues on the fly:

```ruby
Sidekiq::Queue['name'].block
Sidekiq::Queue['name'].blocking? # => true
Sidekiq::Queue['name'].unblock
```

### Advanced blocking queues

You can also block on array of queues. It means when any of them is
running only queues higher and queues from their blocking group can
run. It will be easier to understand with an example:

```yaml
:queues:
  - a
  - b
  - c
  - d
:blocking:
  - [b, c]
```

In this case tasks from `d` will be blocked when a task from queue `b` or `c` is executed.

You can dynamically set exceptions for queue blocking:

```ruby
Sidekiq::Queue['queue1'].block_except 'queue2'
```

### Dynamic queues

You can support dynamic queues (that are not listed in sidekiq.yml but
that have tasks pushed to them (usually with `Sidekiq::Client.push`)).

To use this mode you need to specify a following line in sidekiq.yml:

```yaml
:dynamic: true
```

or

```yaml
  :dynamic:
    :exclude:
      - excluded_queue
```

to exclude `excluded_queue` from dynamic queue

Dynamic queues will be ran at the lowest priority.

### Maintenance

If you use `flushdb`, restart the sidekiq process to re-populate the dynamic configuration.
