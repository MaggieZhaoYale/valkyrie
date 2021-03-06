# frozen_string_literal: true
module Valkyrie
  ##
  # The base resource class for all Valkyrie metadata objects.
  # @example Define a resource
  #   class Book < Valkyrie::Resource
  #     attribute :member_ids, Valkyrie::Types::Array
  #     attribute :author
  #   end
  #
  # @see https://github.com/samvera-labs/valkyrie/wiki/Persistence Resources are persisted by metadata persisters
  # @see https://github.com/samvera-labs/valkyrie/wiki/Queries Resources are retrieved by query adapters
  # @see https://github.com/samvera-labs/valkyrie/wiki/ChangeSets-and-Dirty-Tracking Validation and change tracking is provided by change sets
  #
  # @see lib/valkyrie/specs/shared_specs/resource.rb
  class Resource < Dry::Struct
    include Draper::Decoratable
    constructor_type :schema

    # Overridden to provide default attributes.
    # @note The current theory is that we should use this sparingly.
    def self.inherited(subclass)
      super(subclass)
      subclass.constructor_type :schema
      subclass.attribute :id, Valkyrie::Types::ID.optional, internal: true
      subclass.attribute :internal_resource, Valkyrie::Types::Any.default(subclass.to_s), internal: true
      subclass.attribute :created_at, Valkyrie::Types::DateTime.optional, internal: true
      subclass.attribute :updated_at, Valkyrie::Types::DateTime.optional, internal: true
      subclass.attribute :new_record, Types::Bool.default(true), internal: true
    end

    # @return [Array<Symbol>] Array of fields defined for this class.
    def self.fields
      schema.keys.without(:new_record)
    end

    def self.new(attributes = default_attributes)
      if attributes.is_a?(Hash) && attributes.keys.map(&:class).uniq.include?(String)
        warn "[DEPRECATION] Instantiating a Valkyrie::Resource with strings as keys has " \
             "been deprecated and will be removed in the next major release. " \
             "Please use symbols instead." \
             "Called from #{Gem.location_of_caller.join(':')}"
        attributes = attributes.symbolize_keys
      end
      super
    end

    # Define an attribute. Attributes are used to describe resources.
    # @param name [Symbol]
    # @param type [Dry::Types::Type]
    # @note Overridden from {Dry::Struct} to make the default type
    #   {Valkyrie::Types::Set}
    # @todo Remove ability to override built in attributes.
    def self.attribute(name, type = Valkyrie::Types::Set.optional, internal: false)
      if reserved_attributes.include?(name.to_sym) && schema[name] && !internal
        warn "#{name} is a reserved attribute in Valkyrie::Resource and defined by it. You can remove your definition of `attribute :#{name}`. " \
             "For now your version will be used, but in the next major version the type will be overridden. " \
             "Called from #{Gem.location_of_caller.join(':')}"
        schema.delete(name)
      end
      define_method("#{name}=") do |value|
        set_value(name, value)
      end
      type = type.meta(ordered: true) if name == :member_ids
      super(name, type)
    end

    def self.reserved_attributes
      [:id, :internal_resource, :created_at, :updated_at, :new_record]
    end

    # @return [ActiveModel::Name]
    # @note Added for ActiveModel compatibility.
    def self.model_name
      @model_name ||= ::ActiveModel::Name.new(self)
    end

    delegate :model_name, to: :class

    def self.human_readable_type
      @_human_readable_type ||= name.demodulize.titleize
    end

    def self.human_readable_type=(val)
      @_human_readable_type = val
    end

    def self.enable_optimistic_locking
      attribute(Valkyrie::Persistence::Attributes::OPTIMISTIC_LOCK, Valkyrie::Types::Set.of(Valkyrie::Types::OptimisticLockToken))
    end

    def self.optimistic_locking_enabled?
      schema.key?(Valkyrie::Persistence::Attributes::OPTIMISTIC_LOCK)
    end

    def optimistic_locking_enabled?
      self.class.optimistic_locking_enabled?
    end

    class DeprecatedHashWrite < Hash
      def []=(_k, _v)
        if @soft_frozen
          warn "[DEPRECATION] Writing directly to attributes has been deprecated." \
            " Please use #set_value(k, v) instead or #dup first." \
            " In the next major version, this hash will be frozen. \n" \
            "Called from #{Gem.location_of_caller.join(':')}"
        end
        super
      end

      def delete(*_args)
        if @soft_frozen
          warn "[DEPRECATION] Writing directly to attributes has been deprecated." \
            " Please use #set_value(k, v) instead or #dup first." \
            " In the next major version, this hash will be frozen. \n" \
            "Called from #{Gem.location_of_caller.join(':')}"
        end
        super
      end

      def delete_if(*_args)
        if @soft_frozen
          warn "[DEPRECATION] Writing directly to attributes has been deprecated." \
            " Please use #set_value(k, v) instead or #dup first." \
            " In the next major version, this hash will be frozen. \n" \
            "Called from #{Gem.location_of_caller.join(':')}"
        end
        super
      end

      def soft_freeze!
        @soft_frozen = true
        self
      end

      def soft_thaw!
        @soft_frozen = false
        self
      end

      def dup
        super.soft_thaw!
      end
    end

    # @return [Hash] Hash of attributes
    def attributes
      DeprecatedHashWrite.new.merge(to_h).soft_freeze!
    end

    # @param name [Symbol] Attribute name
    # @return [Boolean]
    def has_attribute?(name)
      respond_to?(name)
    end

    # @param name [Symbol]
    # @return [Symbol]
    # @note Added for ActiveModel compatibility.
    def column_for_attribute(name)
      name
    end

    # @return [Boolean]
    def persisted?
      new_record == false
    end

    def to_key
      [id]
    end

    def to_param
      to_key.map(&:to_s).join('-')
    end

    # @note Added for ActiveModel compatibility
    def to_model
      self
    end

    # @return [String]
    def to_s
      "#{self.class}: #{id}"
    end

    ##
    # Provide a human readable name for the resource
    # @return [String]
    def human_readable_type
      self.class.human_readable_type
    end

    ##
    # Return an attribute's value.
    # @param name [#to_sym] the name of the attribute to read
    def [](name)
      super(name.to_sym)
    rescue NoMethodError
      nil
    end

    ##
    # Set an attribute's value.
    # @param key [#to_sym] the name of the attribute to set
    # @param value [] the value to set key to.
    def set_value(key, value)
      instance_variable_set(:"@#{key}", self.class.schema[key.to_sym].call(value))
    end
  end
end
