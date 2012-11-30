require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class RedisLuaTest < Test::Unit::TestCase

  def feed_redis
    (1..10).each { |e| @redis.set(e.to_s, e) }
  end

  def setup
    @redis = Redis.new(:driver => :hiredis)
    @redis.flushall
    feed_redis
  end


  def test_pass_empty_string_to_lua
    assert_equal "yes", @redis.eval("if ARGV[1] == '' then return 'yes' end", :argv => [""])
  end

  def test_empty_string_isnot_null
    code = <<-EOF
       redis.call("del", "foo")

      if ARGV[1] == nil then
       return "is_nil"
      else
        return "is_not_nil"
      end
    EOF

    assert_equal "is_not_nil" , @redis.eval(code , :argv => [''])
  end


  def test_empty_string_inside_table_flattens_to_empty_string
    code = <<-EOF
      if ARGV[1] == nil then
        return "is_not_nil"
      elseif ARGV[1] == "" then
        return "is_blank"
      end
    EOF

    assert_equal "is_blank" , @redis.eval(code , :argv => [['']])
  end

  def test_ruby_false_is_converted_to_lua_string
    code = <<-EOF
      if ARGV[1] == 'false' then
        return "is_false_string"
      else
        return "is_not_false_string"
      end
    EOF
    assert_equal "is_false_string", @redis.eval(code , :argv => [false])
  end

   def test_for_empty_string
    code = <<-EOF
      if not not tostring(ARGV[1]):find("^%s*$") then
        return "blank_string"
      else
        return "not_blank_string"
      end
    EOF
    assert_equal "blank_string", @redis.eval(code , :argv => [nil])
  end

  def test_return_table_from_lua
    code = <<-EOF
       return {1,2, {1,2,"hola"}, "hola"}
    EOF
    assert_equal [1,2, [1,2,"hola"],"hola"], @redis.eval(code , :argv => [nil])
  end

  def test_return_table_from_lua_inside_pipeline
    res=@redis.pipelined do
      (1..3).each { |e|
        @redis.eval("return {'foo','bar'}")
      }
    end
    assert_equal (1..3).map{ |_| ["foo","bar"]}, res
  end

  def test_tables_in_params_are_strings
    code = <<-EOF
      local t=ARGV[1]
      return type(t)
    EOF
    assert_equal "string", @redis.eval(code, :argv => [["hola", "adiows"]])
  end

  def test_get_value
    assert_equal 8.to_s, @redis.get(8)
  end

  def test_eval_lua
    assert_equal 6, @redis.eval("return ARGV[1] * ARGV[2]", :argv => [2, 3])
  end

  def test_ruby_to_lua_symbol
    assert_equal 'hellofoo', @redis.eval("return 'hello' .. ARGV[1]", :argv => [:foo, :bar])
  end

  def test_nil_is_false
    code = <<-EOC
    if ARGV[1] then
      return 'yes'
    else
      return 'no'
    end
    EOC
    assert_equal "yes", @redis.eval(code, :argv => [nil, 3])
  end

  def test_call_functions_inside_lua
    code = <<-EOF
      local foo = function()
        return 'hi'
      end
      return foo()
    EOF
    assert_equal "hi", @redis.eval(code)
  end

  def test_basic_pipeline
    res=@redis.pipelined do
      (1..10).each { |e|
        @redis.set("#{e}", e)
      }
    end
    res.eql?((1..10).map{|a| 'OK'})
  end

  def test_evalsha
    code = <<-EOC
    if ARGV[1] then
      return 'yes'
    else
      return 'no'
    end
    EOC
    assert_equal "yes", @redis.eval(code, :argv => [nil, 3])
    sha1 = Digest::SHA1.hexdigest code
    assert_equal "yes", @redis.evalsha(sha1, :argv => [nil, 3])
  end


  # def test_dates_inside_lua
  #   t = Time.utc(2010,5,7,12,23,33)
  #   puts @redis.eval("return os.time{year=1992, month=1, day=1, hour=0}")
  # end

  def test_semantic_error_returns_nil
    begin
      return @redis.eval("return ARGV[2]" , :argv => ["hola"]).nil?
    rescue Exception => e
      puts e.inspect
    end
  end

  def test_sintactic_error_raises
    begin
      return @redis.eval("return ARGV[1" , :argv => ["hola"]).nil?
    rescue Redis::CommandError => e
      return true
    end
  end

end
