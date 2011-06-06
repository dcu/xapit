module Xapit
  module Client
    module Membership
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def xapit(&block)
          @xapit_index_builder = IndexBuilder.new
          @xapit_index_builder.instance_eval(&block)
          include AdditionalMethods
        end
      end

      module AdditionalMethods
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          def xapit_index_builder
            @xapit_index_builder
          end

          def search(*args)
            Collection.new.in_classes(self).include_facets(*xapit_index_builder.facets).search(*args)
          end
        end

        def xapit_index
          self.class.xapit_index_builder.index(self)
        end

        def search_similar(*args)
          self.class.search(*args).similar_to(self)
        end
      end
    end
  end
end
