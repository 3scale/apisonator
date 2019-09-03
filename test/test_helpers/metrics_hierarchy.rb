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

    # Extracts from an XML response, the children of the given metric. Note that
    # the XML will only contain that info when the hierarchy extension is
    # enabled.
    def extract_children_from_resp(xml_response_body, parent_name)
      xml_response_body.at('hierarchy')
                       .at("metric[name = '#{parent_name}']")
                       .attribute('children')
                       .value
                       .split # They are separated by spaces
    end
  end
end
