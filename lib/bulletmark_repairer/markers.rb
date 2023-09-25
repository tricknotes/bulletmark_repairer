# frozen_string_literal: true

require 'forwardable'

module BulletmarkRepairer
  class Markers
    extend Forwardable

    def_delegators :@markers, :each, :present?

    def initialize(notifications)
      @markers = {}
      notifications&.each do |notification|
        next unless notification.is_a?(::Bullet::Notification::NPlusOneQuery)

        base_class = notification.instance_variable_get(:@base_class)
        if @markers[base_class]
          @markers[base_class].add_association(notification)
        else
          @markers[base_class] = Marker.new(notification)
        end
      end
    end

    def patching_marker
      @markers.select { |_, marker| marker.patching? }.first.last
    end
  end

  class Marker
    attr_reader :base_class, :associations

    def initialize(notification)
      @base_class = notification.instance_variable_get(:@base_class)
      @stacktraces = notification.instance_variable_get(:@callers)
      @associations = notification.instance_variable_get(:@associations)
      @patching = false
    end

    def add_association(notification)
      @associations += notification.instance_variable_get(:@associations)
    end

    def n_plus_one_in_view?
      @stacktraces.any? { |stacktrace| stacktrace.match?(%r{\A#{Rails.root}/app/views/[./\w]+:\d+:in `[\w]+'\z}) }
    end

    def file_name
      @stacktraces.any? { |stacktrace| stacktrace =~ %r{\A([./\w]+):\d+:in `[\w\s]+'\z} }
      Regexp.last_match[1]
    end

    def line_no
      return @line_no if @line_no

      index = @stacktraces.index { |stacktrace| stacktrace.match?(%r{\A/[./\w]+:\d+:in `block in [\w]+'\z}) }
      @line_no = @stacktraces[index + 1].scan(%r{\A/[./\w]+:(\d+):in `[\w]+'\z}).flatten.first.to_i
    end

    def instance_variable_name_in_view
      return @instance_variable_name_in_view if @instance_variable_name_in_view

      stacktrace_index = @stacktraces.index do |stacktrace|
        stacktrace =~ %r{\A(#{Rails.root}/app/views/[./\w]+):\d+:in `[\w]+'\z} && !Pathname.new(Regexp.last_match(1)).basename.to_s.start_with?('_')
      end
      view_file, yield_index = @stacktraces[stacktrace_index].scan(%r{\A(/[./\w]+):(\d+):in `[\w]+'\z}).flatten
      File.open(view_file) do |f|
        line = f.readlines[yield_index.to_i - 1]
        @instance_variable_finemale_index_in_view = "#{view_file}:#{yield_index}"
        @instance_variable_name_in_view = line.scan(/\b?(@[\w]+)\b?/).flatten.last.to_sym
      end
    end

    def direct_associations
      return @direct_associations if @direct_associations

      instance_variable_name_in_view
      @direct_associations = BulletmarkRepairer.tracers[@instance_variable_finemale_index_in_view]
    end

    def patching?
      @patching == true
    end

    def patching!
      @patching = true
    end

    def patched!
      @patching = false
    end
  end
end
