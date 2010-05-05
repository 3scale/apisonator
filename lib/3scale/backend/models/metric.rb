module ThreeScale
  module Backend
    class Metric < ActiveRecord::Base
      belongs_to :service
  
      named_scope :top_level, :conditions => {:parent_id => nil}
  
      def self.hits
        top_level.find_by_name('hits') || top_level.first
      end
      
      def self.create_default!(type, attributes = {})
        raise 'Only :hits is supported for now' if type != :hits

        create!(attributes.merge(:friendly_name => 'Hits', :name => 'hits', :unit => 'hit',
                                 :description => 'Number of API hits'))
      end
    end
  end
end
