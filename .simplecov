SimpleCov.start do
  command_name "pid-#{Process.pid}"
  add_filter '/test/'
  add_filter '/spec/'
end
