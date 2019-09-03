module TestHelpers
  module MetricsHierarchy

    # Generates a hierarchy of n levels with only one metric per level.
    # Returns an array with the metrics generated. The metric at pos i is the
    # parent of the metric at pos i + 1.
    def gen_hierarchy_one_metric_per_level(service_id, levels)
      metrics = levels.times.map do |level|
        ThreeScale::Backend::Metric.new(
          service_id: service_id, id: next_id, name: "metric_#{level}"
        )
      end

      metrics.each_cons(2) do |parent, child|
        parent.children = [child]
      end

      metrics.first.save # saves all the descendants too

      metrics
    end
  end
end
