job_type :backend_rake, 'cd :path && /usr/local/bin/bundle exec rake2.4 :task --silent'

every 2.minutes do
  backend_rake 'stats:kinesis:send', path: '/home/bender/backend'
end

every 1.hour do
  backend_rake 'stats:redshift:import', path: '/home/bender/backend'
end
