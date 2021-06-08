module TestHelpers
  module Sequences
    @@last_id = 0

    # Generates unique id each time it's called.
    def next_id
      @@last_id += 1
      @@last_id.to_s.encode(Encoding::UTF_8)
    end
  end
end
