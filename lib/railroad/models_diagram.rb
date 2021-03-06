# RailRoad - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details

# RailRoad models diagram
class ModelsDiagram < AppDiagram

  def initialize(options)
    #options.exclude.map! {|e| "app/models/" + e}
    super options
    @graph.diagram_type = 'Models'
    # Processed habtm associations
    @habtm = []
  end

  # Process model files
  def generate
    STDERR.print "Generating models diagram\n" if @options.verbose
    base = "app/models/"
    files = Dir.glob("app/models/**/*.rb")
    files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
    files -= @options.exclude
    files.each do |file|
      model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')
      # Hack to skip all xxx_related.rb files
      next if /_related/i =~ model_name

      klass = begin
        model_name.classify.constantize
      rescue LoadError
        model_name.gsub!(/.*[\/\\]/, '')
        retry
      rescue NameError
        next
      end

      process_class klass
    end
  end

  private

  # Load model classes
  def load_classes
    begin
      disable_stdout
      files = Dir.glob("app/models/**/*.rb")
      files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
      files -= @options.exclude
      files.each do |m|
        require m
      end
      enable_stdout
    rescue LoadError
      enable_stdout
      print_error "model classes"
      raise
    end
  end  # load_classes

  # Process a model class
  def process_class(current_class)

    STDERR.print "\tProcessing #{current_class}\n" if @options.verbose

    generated = false

    # Is current_clas derived from ActiveRecord::Base?
    if current_class.respond_to?'reflect_on_all_associations'
      node_attribs = []
      if @options.brief || current_class.abstract_class? || current_class.superclass != ActiveRecord::Base
        node_type = 'model-brief'
      else
        node_type = 'model'

        # Collect model's content columns

	content_columns = current_class.content_columns

	if @options.hide_magic
          magic_fields = [
          # Restful Authentication
          "login", "crypted_password", "salt", "remember_token", "remember_token_expires_at", "activation_code", "activated_at",
          # From patch #13351
          # http://wiki.rubyonrails.org/rails/pages/MagicFieldNames
          "created_at", "created_on", "updated_at", "updated_on",
          "lock_version", "type", "id", "position", "parent_id", "lft",
          "rgt", "quote", "template"
          ]
          magic_fields << current_class.table_name + "_count" if current_class.respond_to? 'table_name'
          content_columns = current_class.content_columns.select {|c| ! magic_fields.include? c.name}
        else
          content_columns = current_class.content_columns
        end

        content_columns.each do |a|
          content_column = a.name
          content_column += ' :' + a.type.to_s unless @options.hide_types
          node_attribs << content_column
        end
      end
      node_options = {}
      node_options = node_options.merge(:fontsize => @options.fontsize) if @options.fontsize
      @graph.add_node [node_type, current_class.name, node_attribs, node_options]
      generated = true
      # Process class associations
      associations = current_class.reflect_on_all_associations
      if @options.inheritance && ! @options.transitive
        superclass_associations = current_class.superclass.reflect_on_all_associations

        associations = associations.select{|a| ! superclass_associations.include? a}
        # This doesn't works!
        # associations -= current_class.superclass.reflect_on_all_associations
      end
      associations.each do |a|
        process_association current_class.name, a
      end
    elsif @options.all && (current_class.is_a? Class)
      # Not ActiveRecord::Base model
      node_type = @options.brief ? 'class-brief' : 'class'
      @graph.add_node [node_type, current_class.name]
      generated = true
    elsif @options.modules && (current_class.is_a? Module)
        @graph.add_node ['module', current_class.name]
    end

    # Only consider meaningful inheritance relations for generated classes
    if @options.inheritance && generated &&
       (current_class.superclass != ActiveRecord::Base) &&
       (current_class.superclass != Object)
      @graph.add_edge ['is-a', current_class.superclass.name, current_class.name]
    end

  end # process_class

  # Process a model association
  def process_association(class_name, assoc)

    STDERR.print "\t\tProcessing model association #{assoc.name.to_s}\n" if @options.verbose

    # Skip "belongs_to" associations
    return if assoc.macro.to_s == 'belongs_to'

    # Skip through relation if only_simple_edge options
    return if @options.only_simple_edge and assoc.class.to_s =~ /ThroughReflection$/

    # Only non standard association names needs a label

    # from patch #12384
    # if assoc.class_name == assoc.name.to_s.singularize.camelize
    assoc_class_name = (assoc.class_name.respond_to? 'underscore') ? assoc.class_name.underscore.singularize.camelize : assoc.class_name
    if assoc_class_name == assoc.name.to_s.singularize.camelize
      assoc_name = ''
    else
      assoc_name = assoc.name.to_s
    end
#    STDERR.print "#{assoc_name}\n"
    if assoc.macro.to_s == 'has_one'
      assoc_type = 'one-one'
    elsif assoc.macro.to_s == 'has_many' && (! assoc.options[:through])
      assoc_type = 'one-many'
    else # habtm or has_many, :through
      return if @options.only_simple_edge
      return if @habtm.include? [assoc.class_name, class_name, assoc_name]
      assoc_type = 'many-many'
      @habtm << [class_name, assoc.class_name, assoc_name]
    end
    # from patch #12384
    # @graph.add_edge [assoc_type, class_name, assoc.class_name, assoc_name]
    @graph.add_edge [assoc_type, class_name, assoc_class_name, assoc_name]
  end # process_association

end # class ModelsDiagram
