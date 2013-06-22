## Description

Sidekiq strategy to support a granular queue control –
limiting, pausing, blocking, querying.

[![Build Status](https://secure.travis-ci.org/brainopia/sidekiq-limit_fetch.png)](http://travis-ci.org/brainopia/sidekiq-limit_fetch)
[![Gem Version](https://badge.fury.io/rb/sidekiq-limit_fetch.png)](http://badge.fury.io/rb/sidekiq-limit_fetch)
[![Dependency Status](https://gemnasium.com/brainopia/sidekiq-limit_fetch.png)](https://gemnasium.com/brainopia/sidekiq-limit_fetch)
[![Code Climate](https://codeclimate.com/github/brainopia/sidekiq-limit_fetch.png)](https://codeclimate.com/github/brainopia/sidekiq-limit_fetch)

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-limit_fetch'

### Requirements

redis 2.6 or newer

```
heroku uses redis 2.4 by default
to update version you need to contact their support:
https://devcenter.heroku.com/articles/redistogo#redis-26
```

## Usage

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

In these examples, tasks for the ```queue_name1``` will be run by at most 5
workers at the same time and the ```queue_name2``` will have no more than 10
workers simultaneously.

Ability to set limits dynamically allows you to resize worker
distribution among queues any time you want.

### Limits per process

If you use multiple sidekiq processes then you can specify limits per process:

```
  :process_limits:
    queue_name: 2
```

Or set it in your code: ```ruby
  Sidekiq::Queue['queue_name'].process_limit = 2
```

### Busy workers by queue

You can see how many workers currently handling a queue:

```ruby
  Sidekiq::Queue['name'].busy # number of busy workers
```

### Pauses

You can also pause your queues temporarely. Upon continuing their limits
will be preserved.

```ruby
  Sidekiq::Queue['name'].pause # prevents workers from running tasks from this queue
  Sidekiq::Queue['name'].paused? # => true
  Sidekiq::Queue['name'].unpause # allows workers to use the queue
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

### Thanks

Sponsored by [Evil Martians].
[Evil Martians]: http://evilmartians.com/
