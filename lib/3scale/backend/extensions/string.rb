module ThreeScale
  module Backend
    module Extensions
      module String
        def escape_whitespaces
          gsub("_", "\\_").            # escape underscores
          gsub(" ", "_").              # replace spaces with underscores

          # This is bit counterintuitive, but it's right. I need to escape the backslashes
          # twice - first as normal double quoted string, second because the replacement
          # can contain backreferences, so I have to escape those too.
          gsub("\\n", "\\\\\\n").      # escape escaped newlines

          gsub("\n", "\\n")            # escape newlines
        end

        def unescape_whitespaces
          gsub(/(?<!\\)_/, " ").       # replace not-escaped underscores with spaces
          gsub("\\_", "_").            # unescape escaped underscores
          gsub(/(?<!\\)\\n/, "\n").    # unescape escaped newlines
          gsub("\\\\n", "\\n")         # unescape doubly escaped newlines
        end


        def blank?
          self !~ /\S/
        end
      end
    end
  end
end

String.send(:include, ThreeScale::Backend::Extensions::String)
