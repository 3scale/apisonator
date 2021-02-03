module SpecHelpers
  module WorkerHelper
    def process_one_job
      # The async worker creates a reactor and all the tests are run within a
      # reactor (see the config.around(:each) call on spec_helper.rb). To avoid
      # the worker creating a nested reactor inside the one already running, we
      # run Worker.work in its own thread.
      Thread.new { ThreeScale::Backend::Worker.work(one_off: true) }.join
    end
  end
end
