module Representable
  # we don't use keyword args, because i didn't want to discriminate 1.9 users, yet.
  # this will soon get introduces and remove constructs like options[:binding][:default].

  # Deprecation strategy:
  # binding.evaluate_option_with_deprecation(:reader, options, :doc)
  #   => binding.evaluate_option(:reader, options) # always pass in options.

  AssignFragment = ->(input, options) { options[:fragment] = input }

  ReadFragment = ->(input, options) { options[:binding].read(input, options[:as]) }
  Reader = ->(input, options) { options[:binding].evaluate_option(:reader, input, options) }

  StopOnNotFound = ->(input, options) do
    Binding::FragmentNotFound == input ? Pipeline::Stop : input
  end

  StopOnNil = ->(input, options) do # DISCUSS: Not tested/used, yet.
    input.nil? ? Pipeline::Stop : input
  end

  OverwriteOnNil = ->(input, options) do
    input.nil? ? (SetValue.(input, options); Pipeline::Stop) : input
  end

  Default = ->(input, options) do
    Binding::FragmentNotFound == input ? options[:binding][:default] : input
  end

  SkipParse = ->(input, options) do
    options[:binding].evaluate_option(:skip_parse, input, options) ? Pipeline::Stop : input
  end

  Instance = ->(input, options) do
    options[:binding].evaluate_option(:instance, input, options)
  end

  module Function
    class CreateObject
      def call(input, options)
        instance_for(input, options) || class_for(input, options)
      end

    private
      def class_for(input, options)
        item_class = class_from(input, options) or raise DeserializeError.new(":class did not return class constant for `#{options[:binding].name}`.")
        item_class.new
      end

      def class_from(input, options)
        options[:binding].evaluate_option(:class, input, options) # FIXME: no additional args passed here, yet.
      end

      def instance_for(input, options)
        Instance.(input, options)
      end
    end

    class Prepare
      def call(input, options)
        binding = options[:binding]

        binding.evaluate_option(:prepare, input, options)
      end
    end

    class Decorate
      def call(object, options)
        binding = options[:binding]

        return object unless object # object might be nil.

        mod = binding.evaluate_option(:extend, object, options)

        prepare_for(mod, object, binding)
      end

      def prepare_for(mod, object, binding)
        mod.prepare(object)
      end
    end
  end

  CreateObject = Function::CreateObject.new
  Prepare      = Function::Prepare.new
  Decorate     = Function::Decorate.new
  Deserializer =  ->(input, options) { options[:binding].evaluate_option(:deserialize, input, options) }

  Deserialize  =  ->(input, options) do
    binding, fragment, user_options = options[:binding], options[:fragment], options[:user_options]

    user_options = user_options.merge(wrap: binding[:wrap]) unless binding[:wrap].nil? # DISCUSS: can we leave that here?
    puts "@@@@@ds #{options[:user_options].inspect}"
    name = options[:binding].name.to_sym
    user_options = user_options.merge(user_options[name]) if user_options[name]
    puts "user_options #{user_options.inspect}"

    input.send(binding.deserialize_method, fragment, user_options)
  end

  ParseFilter = ->(input, options) do
    options[:binding][:parse_filter].(input, options)
  end

  Setter   = ->(input, options) { options[:binding].evaluate_option(:setter, input, options) }
  SetValue = ->(input, options) { options[:binding].send(:exec_context, options).send(options[:binding].setter, input) }


  Stop = ->(*) { Pipeline::Stop }

  If = ->(input, options) { options[:binding].evaluate_option(:if, nil, options) ? input : Pipeline::Stop }

  StopOnExcluded = ->(input, options) do
    return input unless private = options[:_private]
    return input unless props = (private[:exclude] || private[:include])

    res = props.include?(options[:binding].name.to_sym) # false with include: Stop. false with exclude: go!

    return input if private[:include]&&res
    return input if private[:exclude]&&!res
    Pipeline::Stop
  end
end