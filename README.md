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
  queue_name1: 5
  queue_name2: 10
```

In this example, tasks for the first restricted queue will be run by at most 5
workers at the same time and the second queue will have no more than 10
workers simultaneously.
