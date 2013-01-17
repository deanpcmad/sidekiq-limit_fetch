## Description

Sidekiq strategy to restrict number of workers
which are able to run specified queues simultaneously.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-limit_fetch'

## Usage

Specify limits which you want to place on queues inside sidekiq.yml:

```yaml
:limits:
  queue_name1: 5
  queue_name2: 10
```

Or set it dynamically in your code:
```ruby
  Sidekiq::Queue.new('queue_name1').limit = 5
  Sidekiq::Queue['queue_name2'].limit = 10
```

In these examples, tasks for the ```queue_name1``` will be run by at most 5
workers at the same time and the ```queue_name2``` will have no more than 10
workers simultaneously.

Ability to set limits dynamically allows you to resize worker
distribution among queues any time you want.

Limits are applied strictly for current process.

Sponsored by [Evil Martians].
[Evil Martians]: http://evilmartians.com/
