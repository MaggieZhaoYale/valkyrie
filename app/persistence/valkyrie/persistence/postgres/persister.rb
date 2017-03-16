# frozen_string_literal: true
module Valkyrie::Persistence::Postgres
  class Persister
    class << self
      def save(model)
        instance(model).persist
      end

      def delete(model)
        instance(model).delete
      end

      def sync_object(model)
        ::Valkyrie::Persistence::Postgres::ORMSyncer.new(model: model)
      end

      def post_processors(model)
        [Valkyrie::Processors::AppendProcessor.new(form: model, persister: self)]
      end

      def adapter
        Valkyrie::Persistence::Postgres
      end

      def instance(model)
        new(sync_object: sync_object(model), post_processors: post_processors(model))
      end
    end

    attr_reader :post_processors, :sync_object
    delegate :model, to: :sync_object

    def initialize(sync_object: nil, post_processors: [])
      @sync_object = sync_object
      @post_processors ||= post_processors
    end

    def persist
      sync_object.save
      post_processors.each do |processor|
        processor.run(model: model)
      end
      model
    end

    def delete
      sync_object.delete
      model
    end
  end
end
