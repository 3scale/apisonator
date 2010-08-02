require File.dirname(__FILE__) + '/../test_helper'

class StringHacksTest < Test::Unit::TestCase
  def test_escape_whitespaces_replaces_spaces_with_underscores
    assert_equal "foo_bar", "foo bar".escape_whitespaces
  end
  
  def test_escape_whitespaces_escapes_underscores
    assert_equal "foo\\_bar", "foo_bar".escape_whitespaces
  end

  def test_escape_whitespaces_escapes_newlines
    assert_equal "foo\\nbar", "foo\nbar".escape_whitespaces
  end
  
  def test_escape_whitespaces_escapes_escaped_newlines
    assert_equal "foo\\\\nbar", "foo\\nbar".escape_whitespaces
  end

  def test_unescape_whitespaces_replaces_underscores_with_spaces
    assert_equal "foo bar", "foo_bar".unescape_whitespaces
  end

  def test_unescape_whitespaces_unescapes_escaped_underscores
    assert_equal "foo_bar", "foo\\_bar".unescape_whitespaces
  end

  def test_unescape_whitespaces_unescapes_escaped_newlines
    assert_equal "foo\nbar", "foo\\nbar".unescape_whitespaces
  end

  def test_unescape_whitespaces_unescapes_doubly_escaped_newlines
    assert_equal "foo\\nbar", "foo\\\\nbar".unescape_whitespaces
  end

  def test_escape_whitespaces_is_inverse_of_unescape_whitespaces
    samples = ["foo bar", "foo_bar", "foo\\_bar", "foo\nbar", "foo\\nbar", 
               "foo\\\\nbar", "foo\\\\\\nbar"]
    samples.each do |sample|
      assert_equal sample, sample.escape_whitespaces.unescape_whitespaces
    end
  end
end
