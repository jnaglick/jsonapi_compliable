# TODO: refactor - code could be better but it's a one-time thing.

module JsonapiCompliable
  class Query
    attr_reader :params, :resource

    def self.default_hash
      {
        filter: {},
        sort: [],
        page: {},
        include: {},
        stats: {},
        fields: {},
        extra_fields: {}
      }
    end

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def to_hash
      hash = { resource.type => self.class.default_hash }
      resource.association_names.each do |name|
        hash[name] = self.class.default_hash.except(:include)
      end

      fields = parse_fields({}, :fields)
      extra_fields = parse_fields({}, :extra_fields)
      hash.each_pair do |type, query_hash|
        hash[type][:fields] = fields
        hash[type][:extra_fields] = extra_fields
      end

      parse_filter(hash)
      parse_sort(hash)
      parse_pagination(hash)
      parse_include(hash)
      parse_stats(hash)

      hash
    end

    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    private

    def association?(name)
      resource.association_names.include?(name)
    end

    def parse_include(hash)
      hash[resource.type][:include] = JSONAPI::IncludeDirective.new(params[:include] || {}).to_hash
    end

    def parse_stats(hash)
      if params[:stats]
        params[:stats].each_pair do |namespace, calculations|
          if namespace == resource.type || association?(namespace)
            calculations.each_pair do |name, calcs|
              hash[namespace][:stats][name] = calcs.split(',').map(&:to_sym)
            end
          else
            hash[resource.type][:stats][namespace] = calculations.split(',').map(&:to_sym)
          end
        end
      end
    end

    def parse_fields(hash, type)
      field_params = Util::FieldParams.parse(params[type])
      hash[type] = field_params
    end

    def parse_filter(hash)
      if filter = params[:filter]
        filter.each_pair do |key, value|
          key = key.to_sym

          if association?(key)
            hash[key][:filter].merge!(value)
          else
            hash[resource.type][:filter][key] = value
          end
        end
      end
    end

    def parse_sort(hash)
      if sort = params[:sort]
        sorts = sort.split(',')
        sorts.each do |s|
          if s.include?('.')
            type, attr = s.split('.')
            if type.starts_with?('-')
              type = type.sub('-', '')
              attr = "-#{attr}"
            end

            hash[type.to_sym][:sort] << sort_attr(attr)
          else
            hash[resource.type][:sort] << sort_attr(s)
          end
        end
      end
    end

    def parse_pagination(hash)
      if pagination = params[:page]
        pagination.each_pair do |key, value|
          key = key.to_sym

          if [:number, :size].include?(key)
            hash[resource.type][:page][key] = value.to_i
          else
            hash[key][:page] = { number: value[:number].to_i, size: value[:size].to_i }
          end
        end
      end
    end

    def sort_attr(attr)
      value = attr.starts_with?('-') ? :desc : :asc
      key   = attr.sub('-', '').to_sym

      { key => value }
    end
  end
end
