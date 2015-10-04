module Representable::Hash
  module Collection
    include Representable::Hash

    def self.included(base)
      base.class_eval do
        include Representable::Hash
        extend ClassMethods
        representable_attrs.add(:_self, {:collection => true})
      end
    end


    module ClassMethods
      def items(options={}, &block)
        collection(:_self, options.merge(:getter => lambda { |*| self }), &block)
      end
    end


    def create_representation_with(doc, options, format)
      bin   = representable_mapper(format, options).bindings(represented, options).first
      bin.render_fragment(represented, doc)
    end

    def update_properties_from(doc, options, format)
      bin   = representable_mapper(format, options).bindings(represented, options).first
      # value = Deserializer::Collection.new(bin).call(doc)

      # Populator.new(bin).call()
      if bin.typed?
        value = Collect[SkipParse, CreateObject, Prepare, Deserialize].
          (fragment: doc, document: doc, binding: bin)
      else
value = Collect[SkipParse].
          (fragment: doc, document: doc, binding: bin)
      end


      represented.replace(value)
    end
  end
end
