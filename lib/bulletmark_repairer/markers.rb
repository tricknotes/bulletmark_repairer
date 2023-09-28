# frozen_string_literal: true

require 'forwardable'

module BulletmarkRepairer
  class Markers
    extend Forwardable

    def_delegator :@markers, :each

    def initialize(notifications, controller:, action:)
      @markers = {}
      notifications.collection.to_a.each do |notification|
        next unless notification.is_a?(::Bullet::Notification::NPlusOneQuery)

        base_class = notification.instance_variable_get(:@base_class)
        if @markers[base_class]
          @markers[base_class].add_association(notification)
        else
          @markers[base_class] = Marker.new(
            notification,
            controller:,
            action:
          )
        end
      end
    end
  end

  class Marker
    attr_reader :base_class, :associations, :action, :file_name, :line_no, :instance_variable_name_in_view

    def initialize(notification, controller:, action:)
      @base_class = notification.instance_variable_get(:@base_class)
      @stacktraces = notification.instance_variable_get(:@callers)
      @associations = notification.instance_variable_get(:@associations)
      @controller = controller
      @action = action
      set_up
    end

    def add_association(notification)
      @associations += notification.instance_variable_get(:@associations)
    end

    def direct_associations
      return @direct_associations if @direct_associations

      @direct_associations = if n_plus_one_in_view?
                               BulletmarkRepairer.tracers[@instance_variable_finemale_index_in_view]
                             else
                               associations
                             end
    end

    def n_plus_one_in_view?
      @n_plus_one_in_view
    end

    def index
      "#{file_name}:#{line_no}"
    end

    private

    def set_up
      @n_plus_one_in_view = @stacktraces.any? { |stacktrace| stacktrace.match?(%r{\A#{Rails.root}/app/views/[./\w]+:\d+:in `[\w]+'\z}) }

      if n_plus_one_in_view?
        @file_name = "#{Rails.root}/app/controllers/#{@controller}_controller.rb"
        @stacktraces
          .index do |stacktrace|
            stacktrace =~ %r{\A(#{Rails.root}/app/views/[./\w]+):\d+:in `[\w]+'\z} && !Pathname.new(Regexp.last_match(1)).basename.to_s.start_with?('_')
          end.tap do |stacktrace_index|
            view_file, yield_index = @stacktraces[stacktrace_index].scan(%r{\A(/[./\w]+):(\d+):in `[\w]+'\z}).flatten
            File.open(view_file) do |f|
              line = f.readlines[yield_index.to_i - 1]
              @instance_variable_name_in_view = line.scan(/\b?(@[\w]+)\b?/).flatten.last
              @instance_variable_finemale_index_in_view = "#{view_file}:#{yield_index}"
            end
          end
      else
        @stacktraces.any? { |stacktrace| stacktrace =~ %r{\A([./\w]+):\d+:in `[\w\s]+'\z} }.tap do
          @file_name = Regexp.last_match[1]
        end
        @instance_variable_name_in_view = nil
        @instance_variable_finemale_index_in_view = nil
      end

      @stacktraces.index { |stacktrace| stacktrace.match?(%r{\A/[./\w]+:\d+:in `block in [\w]+'\z}) }.tap do |line_no_index|
        @line_no = @stacktraces[line_no_index + 1].scan(%r{\A/[./\w]+:(\d+):in `[\w]+'\z}).flatten.first.to_i
      end
    end
  end
end
