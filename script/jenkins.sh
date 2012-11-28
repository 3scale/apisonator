sudo /etc/init.d/cassandra start;
sleep 15;
RAILS_ENV=test ~/.rvm/bin/ruby-1.9.2-p180 ~/.rvm/gems/ruby-1.9.2-p180/bin/bundle install && ~/.rvm/bin/ruby-1.9.2-p180 ~/.rvm/gems/ruby-1.9.2-p180/bin/bundle exec ~/.rvm/bin/rake-ruby-1.9.2-p180;
export RET=$?;
sudo /etc/init.d/cassandra stop;
(($RET == 0))
