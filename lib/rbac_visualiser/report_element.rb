module RbacVisualiser
  module ReportElement
    extend self
    
    def get attrs
      @data = attrs.fetch(:data)
      @writer = attrs.fetch(:writer)
      @items = items

      {
        severity: @items.blank? ? :success : attrs.fetch(:severity).to_sym,
        group_title: attrs.fetch(:group_title),
        info: attrs.fetch(:info),
        items: @items
      }
    end

    private

    def items
      if @data.is_a?(Set)
        elements = @data.to_a
      else
        columns = @data.columns
        elements = @data.resultset
      end

      return nil if elements.blank?

      elements.to_a.collect do |r|
        record = if r.is_a?(Hash)
          r
        else 
          # redisgraph-rb doesn't return hash records so making one up
          columns.zip(r).to_h.with_indifferent_access
        end
        @writer.call(record) if @writer
      end.compact.uniq
    end

  end
end
