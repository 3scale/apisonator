require 'json'

module Serialize
  def self.included(base)
    base.extend(ClassMethods)
  end

  def initialize(params = {})
    self.class.const_get(:ATTRIBUTES).each do |key|
      send("#{key}=", params[key]) unless params[key].nil?
    end
  end

  def to_json
    Hash[self.class.const_get(:ATTRIBUTES).collect { |key| [key, send(key)] }].to_json
  end

  module ClassMethods
    def parse_json(o_str)
      new(JSON.parse(o_str, symbolize_names: true))
    end
  end
end
