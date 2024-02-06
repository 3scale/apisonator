module SpecHelpers
  module WorkerHelper
    def process_one_job
      # The async worker creates a reactor and all the tests are run within a
      # reactor (see the config.around(:each) call on spec_helper.rb).
      # To ensure the job is processed, we wait until it finishes
      Sync { ThreeScale::Backend::Worker.work(one_off: true) }
    end
  end
end
