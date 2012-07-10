# RailRoad - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details


# RailRoad diagram structure
class DiagramGraph

  def initialize(origin_name, opts={})
    @diagram_type = ''
    @show_label = false
    @nodes = []
    @edges = []
    @origin_name = origin_name
    @size = opts[:size] && {:x => opts[:size][0], :y => opts[:size][1]}
  end

  def add_node(node)
    @nodes << node
  end

  def add_edge(edge)
    @edges << edge
  end

  def diagram_type= (type)
    @diagram_type = type
  end

  def show_label= (value)
    @show_label = value
  end


  # Generate DOT graph
  def to_dot(n=0)
    neighborhood_nodes, neighborhood_edges = delete_far_node_from(@nodes, @edges, @origin_name, n)

    return dot_header +
           (@nodes - neighborhood_nodes).map{|n| dot_node n[0], n[1], n[2], n[3]}.join +
           (@edges - neighborhood_edges).map{|e| dot_edge e[0], e[1], e[2], e[3]}.join +
           dot_footer
  end

  # Generate XMI diagram (not yet implemented)
  def to_xmi
     STDERR.print "Sorry. XMI output not yet implemented.\n\n"
     return ""
  end

  private

  # Build DOT diagram header
  def dot_header
    graph_options = {:overlap => false, :splines => true}
    graph_options = graph_options.merge({:size => %Q|"#{@size[:x]},#{@size[:y]}"|}) if @size
    result = "digraph #{@diagram_type.downcase}_diagram {\n" +
             "\tgraph[#{graph_options.map{|k,v| "#{k}=#{v}"}.join(' ')}]\n"
    result += dot_label if @show_label
    return result
  end

  # Build DOT diagram footer
  def dot_footer
    return "}\n"
  end

  # Build diagram label
  def dot_label
    return "\t_diagram_info [shape=\"plaintext\", " +
           "label=\"#{@diagram_type} diagram\\l" +
           "Date: #{Time.now.strftime "%b %d %Y - %H:%M"}\\l" +
           "Migration version: " +
           "#{ActiveRecord::Migrator.current_version}\\l" +
           "Generated by #{APP_HUMAN_NAME} #{APP_VERSION.join('.')}"+
           "\\l\", fontsize=14]\n"
  end

  # Build a DOT graph node
  def dot_node(type, name, attributes=nil, node_options={})
    case type
      when 'model'
           options = 'shape=Mrecord, label="{' + name + '|'
           options += attributes.join('\l')
           options += '\l}"'
      when 'model-brief'
           options = ''
      when 'class'
           options = 'shape=record, label="{' + name + '|}"'
      when 'class-brief'
           options = 'shape=box'
      when 'controller'
           options = 'shape=Mrecord, label="{' + name + '|'
           public_methods    = attributes[:public].join('\l')
           protected_methods = attributes[:protected].join('\l')
           private_methods   = attributes[:private].join('\l')
           options += public_methods + '\l|' + protected_methods + '\l|' +
                      private_methods + '\l'
           options += '}"'
      when 'controller-brief'
           options = ''
      when 'module'
           options = 'shape=box, style=dotted, label="' + name + '"'
      when 'aasm'
           # Return subgraph format
           return "subgraph cluster_#{name.downcase} {\n\tlabel = #{quote(name)}\n\t#{attributes.join("\n  ")}}"
    end # case

    options += ', ' + node_options.map{|k, v| "#{k}=#{v}"}.join(', ') unless node_options == {}

    return "\t#{quote(name)} [#{options}]\n"
  end # dot_node

  # Build a DOT graph edge
  def dot_edge(type, from, to, name = '')
    options =  name != '' ? "label=\"#{name}\", " : ''
    case type
      when 'one-one'
           #options += 'taillabel="1"'
           options += 'arrowtail=odot, arrowhead=dot, dir=both'
      when 'one-many'
	   #options += 'taillabel="n"'
           options += 'arrowtail=crow, arrowhead=dot, dir=both'
      when 'many-many'
           #options += 'taillabel="n", headlabel="n", arrowtail="normal"'
           options += 'arrowtail=crow, arrowhead=crow, dir=both'
      when 'is-a'
           options += 'arrowhead="none", arrowtail="onormal"'
      when 'event'
           options += "fontsize=10"
    end
    return "\t#{quote(from)} -> #{quote(to)} [#{options}]\n"
  end # dot_edge

  # Quotes a class name
  def quote(name)
    '"' + name.to_s + '"'
  end

  # originよりstepより離れているノードは削除する
  def delete_far_node_from(nodes, edges, origin_name, step=3)
    node_classes = []

    wanna_delete_names = [origin_name]
    (step || 0).times do |i|
      nodes, edges, wanna_delete_names = delete_connected_nodes(nodes, edges, wanna_delete_names)
    end
    return [nodes, edges]
  end

  # nodesとそのedgeを削除し、つながるnodeの集合を返す
  def delete_connected_nodes(nodes, edges, wanna_delete_names)
    raise "nodes(=#{nodes.inspect}) is wrong." unless nodes.all?{|e| 3 <= e.size }
    raise "edges(=#{edges.inspect}) is wrong." unless edges.all?{|e| e.size == 4}
    raise "wanna_delete_names(=#{edges.inspect}) is wrong." unless wanna_delete_names.all?{|e| e.kind_of?(String)}

    deleted_names = []

    wanna_delete_names.each do |n|
      connected_edges = edges.select{|_, c1, c2, __| c1 == n || c2 == n}

      edges = edges - connected_edges
      nodes = nodes.reject{|_, n2, __| n2 == n}

      # TODO: 以下がちゃんとノードの配列に成っているか?
      deleted_names += connected_edges.map{|_, c1, c2, __| [c1, c2]}.flatten
    end

    return [nodes, edges, deleted_names]
  end

end # class DiagramGraph
