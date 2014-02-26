This is a demo rails app with a configured sidekiq-limit_fetch.

Its purpose is to check whether plugin works in certain situations.

Application is preconfigured with two workers:
- `app/workers/fast_worker.rb` which does `sleep 0.2`
- `app/workers/slow_worker.rb` which does `sleep 1`

There is also a rake task which can be invoked as `bundle exec rake demo:limit`:

- it prefills sidekiq tasks

```ruby
  100.times do
    SlowWorker.perform_async
    FastWorker.perform_async
  end
```
- sets sidekiq config

```yaml
  :verbose: false
  :concurrency: 4
  :queues:
    - slow
    - fast
  :limits:
    slow: 1
```

- and launches a sidekiq admin page with overview of queues in browser.
The page is set to live-poll so effects of limits can be seen directly.


To change simulation modify `Rakefile` or workers.

Any bugs related to the plugin should be demonstrated with a reproduction from this base app.
