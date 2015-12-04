require 'chef/node/attribute_constants'
require 'chef/node/attribute_cell'
require 'chef/node/set_unless'
require 'chef/node/attribute_trait/decorator'
require 'chef/node/attribute_trait/convert_value'
require 'chef/node/attribute_trait/stringize'
require 'chef/node/attribute_trait/methodize'
require 'chef/node/attribute_trait/immutablize'

class Chef
  class Node
    class Attribute
      include AttributeTrait::Decorator
      include AttributeTrait::ConvertValue
      include AttributeTrait::Stringize
      include AttributeTrait::Methodize
      include AttributeTrait::Immutablize
      include AttributeConstants

      def initialize(normal, default, override, automatic)
        @wrapped_object = AttributeCell.new(
            default: default,
            env_default: {},
            role_default: {},
            force_default: {},
            normal: normal,
            override: override,
            role_override: {},
            env_override: {},
            force_override: {},
            automatic: automatic,
        )
      end

      COMPONENTS_AS_SYMBOLS.each do |component|
        attr_writer component

        define_method component do
          wrapped_object.public_send(component)
        end

        define_method :"#{component}=" do |value|
          wrapped_object.public_send(:"#{component}=", value)
        end
      end

      def combined_default
        wrapped_object.combined_default
      end

      def combined_override
        wrapped_object.combined_override
      end

      def normal_unless
        SetUnless.new_decorator(wrapped_object: wrapped_object.normal)
      end

      def default_unless
        SetUnless.new_decorator(wrapped_object: wrapped_object.default)
      end

      def override_unless
        SetUnless.new_decorator(wrapped_object: wrapped_object.override)
      end

      # should deprecate all of these, epecially #set
      alias_method :set, :normal
      alias_method :set_unless, :normal_unless
      alias_method :default_attrs, :default
      alias_method :default_attrs=, :default=
      alias_method :normal_attrs, :normal
      alias_method :normal_attrs=, :normal=
      alias_method :override_attrs, :override
      alias_method :override_attrs=, :override=
      alias_method :automatic_attrs, :automatic
      alias_method :automatic_attrs=, :automatic=

      def has_key?(key)
        self.public_send(:key?, key)
      end

      alias_method :attribute?, :has_key?
      alias_method :member?, :has_key?
      alias_method :include?, :has_key?

      def each_attribute(&block)
        self.public_send(:each, &block)
      end

      # Debug what's going on with an attribute. +args+ is a path spec to the
      # attribute you're interested in. For example, to debug where the value
      # of `node[:network][:default_interface]` is coming from, use:
      #   debug_value(:network, :default_interface).
      # The return value is an Array of Arrays. The first element is
      # `["set_unless_enabled?", Boolean]`, which describes whether the
      # attribute collection is in "set_unless" mode. The rest of the Arrays
      # are pairs of `["precedence_level", value]`, where precedence level is
      # the component, such as role default, normal, etc. and value is the
      # attribute value set at that precedence level. If there is no value at
      # that precedence level, +value+ will be the symbol +:not_present+.
      def debug_value(*args)
        COMPONENTS_AS_SYMBOLS.map do |component|
          ivar = wrapped_object.send(component)
          value = args.inject(ivar) do |so_far, key|
            if so_far == :not_present
              :not_present
            elsif so_far.has_key?(key)
              so_far[key]
            else
              :not_present
            end
          end
          [component.to_s, value]
        end
      end

      def to_s
        wrapped_object.to_s
      end

      def eql?(other)
        wrapped_object.eql?(other)
      end

      def ===(other)
        wrapped_object === other
      end

      def ==(other)
        wrapped_object == other
      end

      def kind_of?(klass)
        wrapped_object.kind_of?(klass) || super(klass)
      end

      def is_a?(klass)
        wrapped_object.is_a?(klass) || super(klass)
      end

      def kind_of?(klass)
        wrapped_object.kind_of?(klass) || super(klass)
      end

      def inspect
        wrapped_object.inspect
      end

      # clears attributes from all precedence levels
      #
      # does not autovivify
      def rm(*args)
        raise "unimplemented"
      end

      # clears attributes from all default precedence levels
      #
      # equivalent to: force_default!['foo']['bar'].delete('baz')
      #
      # does not autovivify
      def rm_default(*args)
        raise "unimplemented"
      end

      # clears attributes from normal precedence
      #
      # equivalent to: normal!['foo']['bar'].delete('baz')
      #
      # does not autovivify
      def rm_normal(*args)
        raise "unimplemented"
      end

      # clears attributes from all override precedence levels
      #
      # equivalent to: force_override!['foo']['bar'].delete('baz')
      #
      # does not autovivify
      def rm_override(*args)
        raise "unimplemented"
      end

      def default!(*args)
        raise "unimplemented"
      end

      def normal!(*args)
        raise "unimplemented"
      end

      def override!(*args)
        raise "unimplemented"
      end

      def force_default!(*args)
        raise "unimplemented"
      end

      def force_override!(*args)
        raise "unimplemented"
      end
    end
  end
end
