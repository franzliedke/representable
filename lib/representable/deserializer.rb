module Representable
  # Deserializer's job is deserializing the already parsed fragment into a scalar or an object.
  # This object is then returned to the Populator.
  #
  # It respects :deserialize, :prepare, :class, :instance
  #
  # Collection bindings return an array of parsed fragment items (still native format, e.g. Nokogiri node, for nested objects).
  #
  # Workflow
  #   call -> instance/class -> prepare -> deserialize -> from_json.
  class Deserializer
    def initialize(binding)
      @binding = binding
    end

    # Workflow: binding.set(Deserializer.(fragment))
    def call(fragment, object, *args) # FIXME: args is always i.
      return fragment unless @binding.typed? # customize with :extend. this is not really straight-forward.
      return object unless @binding.representable?
      # return fragment if fragment.nil?

      # what if create_object is responsible for providing the deserialize-to object?
      # object        = create_object(fragment, *args) # customize with :instance and :class.
      # representable = prepare(object) # customize with :prepare and :extend.

      deserialize(object, fragment, @binding.user_options) # deactivate-able via :representable => false.
    end

  private
    def deserialize(object, fragment, options) # TODO: merge with #serialize.
      @binding.evaluate_option(:deserialize, object, fragment) do
        demarshal(object, fragment, options) # object.from_hash.
      end
    end

    def demarshal(object, fragment, options)
      object.send(@binding.deserialize_method, fragment, options)
    end

    module Prepare
      def prepare(object)
        @binding.evaluate_option(:prepare, object) do
          prepare!(object)
        end
      end

      def prepare!(object)
        mod = @binding.representer_module_for(object)

        return object unless mod

        prepare_for(mod, object)
      end

      def prepare_for(mod, object)
        mod.prepare(object)
      end
    end
    include Prepare

    def create_object(fragment, *args)
      instance_for(fragment, *args) or class_for(fragment, *args)
    end

    def class_for(fragment, *args)
      item_class = class_from(fragment, *args) or raise DeserializeError.new(":class did not return class constant.")
      item_class.new
    end

    def class_from(fragment, *args)
      @binding.evaluate_option(:class, fragment, *args)
    end

    def instance_for(fragment, *args)
      # cool: if no :instance set, { return } will jump out of this method.
      @binding.evaluate_option(:instance, fragment, *args) { return } or raise DeserializeError.new(":instance did not return object.")
    end



    # Collection does exactly the same as Deserializer but for a collection.
    # class Collection < self
    #   def call(fragment, object)
    #     collection = [] # this can be replaced, e.g. AR::Collection or whatever.

    #     fragment.each_with_index do |item_fragment, i|
    #       # add more per-item options here!
    #       next if @binding.evaluate_option(:skip_parse, item_fragment) # TODO: pass in index!

    #       collection << deserialize!(item_fragment, i) # FIXME: what if obj nil?
    #     end

    #     collection # with parse_strategy: :sync, this is ignored.
    #   end

    # private
    #   def deserialize!(*args)
    #     item_deserializer.call(*args)
    #   end

    #   def item_deserializer
    #     @item_deserializer = Deserializer.new(@binding)
    #   end
    # end


    class Hash < self# Collection
      def call(hash)
        {}.tap do |hsh|
          hash.each { |key, fragment| hsh[key] = deserialize!(fragment) }
        end
      end
    end
  end
end