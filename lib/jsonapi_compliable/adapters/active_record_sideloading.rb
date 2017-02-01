module JsonapiCompliable
  module Adapters
    module ActiveRecordSideloading
      def has_many(association_name, scope:, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, resource: resource do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(primary_key) }
            _scope.call.where(foreign_key => parent_ids)
          end

          assign do |parents, children|
            parents.each do |parent|
              parent.association(association_name).loaded!
              relevant_children = children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
              relevant_children.each do |c|
                parent.association(association_name).add_to_target(c, :skip_callbacks)
              end
            end
          end

          instance_eval(&blk) if blk
        end
      end

      def belongs_to(association_name, scope:, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, resource: resource do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(foreign_key) }
            _scope.call.where(primary_key => parent_ids)
          end

          assign do |parents, children|
            parents.each do |parent|
              relevant_child = children.find { |c| parent.send(foreign_key) == c.send(primary_key) }
              parent.send(:"#{association_name}=", relevant_child)
            end
          end
        end

        instance_eval(&blk) if blk
      end

      def has_one(association_name, scope:, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, resource: resource do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(primary_key) }
            _scope.call.where(foreign_key => parent_ids)
          end

          assign do |parents, children|
            parents.each do |parent|
              parent.association(association_name).loaded!
              relevant_child = children.find { |c| c.send(foreign_key) == parent.send(primary_key) }
              next unless relevant_child
              parent.send(:"#{association_name}=", relevant_child)
            end
          end

          instance_eval(&blk) if blk
        end
      end
    end
  end
end
