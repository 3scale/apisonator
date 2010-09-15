module ThreeScale
  module Backend
    module Validators
      class Domain < Base
        def apply
          if application.has_domain_constraints?
            if application.has_domain_constraint?(params[:domain])
              succeed!
            else
              fail!(DomainInvalid.new(params[:domain]))
            end
          else
            succeed!
          end
        end

        # TODO: wildcard domain match: *.example.org
      end
    end
  end
end
