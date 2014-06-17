# A velvet Graph where the nodes and arcs are in Ruby, but the NodedReads are in C
class Bio::FinishM::HybridGraph
  include Bio::FinishM::Logging

  attr_reader :nodes

  def initialize(bio_velvet_graph, bio_velvet_underground_graph)
    @bio_velvet_graph = bio_velvet_graph
    @bio_velvet_underground_graph = bio_velvet_underground_graph

    @nodes = NodeArray.new(bio_velvet_graph, bio_velvet_underground_graph, self)
  end

  def method_missing(method_sym, *args, &block)
    @bio_velvet_graph.send(method_sym, *args, &block)
  end

  class NodeArray
    include Enumerable

    def initialize(bio_velvet_graph, bio_velvet_underground_graph, parent_graph)
      @bio_velvet_graph = bio_velvet_graph
      @bio_velvet_underground_graph = bio_velvet_underground_graph
      @parent_graph = parent_graph
    end

    def []=(node_id, value)
      raise "method not implemented"
    end

    def [](node_id)
      bio_velvet_node = @bio_velvet_graph.nodes[node_id]
      bio_velvet_node.short_reads = @bio_velvet_underground_graph.nodes[node_id].short_reads
      bio_velvet_node.parent_graph = @parent_graph
      return bio_velvet_node
    end

    def delete(node)
      raise "method not implemented"
    end

    def length
      @bio_velvet_graph.nodes.length
    end

    def each(&block)
      @bio_velvet_graph.nodes.each do |node|
        block.yield self[node.node_id]
      end
    end
  end
end