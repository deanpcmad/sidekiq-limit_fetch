## Description

Sidekig strategy to restrict number of workers
which are able to run specified queues simultaneously.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-limit_fetch'

## Usage

Specify limits which you want to place on queues inside sidekiq.yml:

```yaml
:limits:
  restricted_queue: 5
```

In this example, tasks for restricted queue will be run by at most 5
workers at the same time.
