Dir[File.join(File.dirname(__FILE__), 'helpers', '*.rb')].each do |f|
  require f
end
