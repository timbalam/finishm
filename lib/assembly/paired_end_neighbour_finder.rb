class Bio::FinishM::PairedEndNeighbourFinder
  include Bio::FinishM::Logging

  # parameters for exploration (and code optimisation, actually)
  attr_accessor :min_adjoining_reads, :max_adjoining_node_coverage

  def initialize(finishm_graph, insert_size)
    @finishm_graph = finishm_graph
    @insert_size = insert_size
  end

  # Return an array of Neighbour objects that are adjoined either directly through the
  # de-Bruijn graph or through paired-end connections
  def neighbours(oriented_node)
    direct_neighbours = oriented_node.next_neighbours(@finishm_graph.graph)
    paired_neighbours = paired_neighbour_distances(oriented_node)

    # Return a dereplicated set, prefer direct connections to paired connections
    dereplicated = {}
    direct_neighbours.each do |oneigh|
      key = oneigh.node_id
      raise if dereplicated[key]
      n = Neighbour.new
      n.node = oneigh.node
      n.first_side = oneigh.first_side
      n.connection_type = Neighbour::DIRECT_CONNECTION
      n.distance = 0
      dereplicated[key] = n
    end
    paired_neighbours.each do |n|
      key = n.node.node_id
      next if dereplicated[key] #skip those already connected by direct connection
      dereplicated[key] = n
    end
    return dereplicated.values
  end

  # Return an array of Neighbour objects representing nodes that has reads which
  # are paired with reads of the given node. Each distance is the estimated
  # distance separating the nodes.
  def paired_neighbour_distances(oriented_node)
    # Collect a list of node IDs that have a sufficient number of connections
    #hash of node ID to Array of [first_read, second_read_id] where first_read is on the current
    # node and second_read is on the neighbour
    neighbour_node_read_pairs = {}
    oriented_node.node.short_reads.each do |read|
      # skip reads not going in the direction consistent with direction of travel
      next unless (read.direction == true and oriented_node.first_side == Bio::Velvet::Graph::OrientedNodeTrail::START_IS_FIRST) or
      (read.direction == false and oriented_node.first_side == Bio::Velvet::Graph::OrientedNodeTrail::END_IS_FIRST)

      pair_read_id = @finishm_graph.velvet_sequences.pair_id(read.read_id)
      unless pair_read_id.nil? #i.e. if read is paired
        @finishm_graph.read_to_nodes[pair_read_id].each do |node_id|
          neighbour_node_read_pairs[node_id] ||= []
          neighbour_node_read_pairs[node_id] << [read, pair_read_id]
        end
      end
    end

    # Create a hash of paired node_ids to [fwd_noded_read, rev_noded_read]
    node_ids_to_read_and_pair = {}
    neighbour_node_read_pairs.each do |neighbour_node_id, pairs|
      next if (@min_adjoining_reads and pairs.length < @min_adjoining_reads)

      # ignore neighbours that have too much coverage, these are likely
      # to be incorrect connections e.g. adapter contamination
      neighbour_node = @finishm_graph.graph.nodes[neighbour_node_id]
      log.debug "Found neighbour node coverage #{neighbour_node.coverage}" if log.debug?
      if @max_adjoining_node_coverage and neighbour_node.coverage > @max_adjoining_node_coverage
        log.debug "Skipping node #{neighbour_node} as it has coverage #{neighbour_node.coverage} not < #{@max_adjoining_node_coverage}" if log.debug?
        next
      end

      node_ids_to_read_and_pair[neighbour_node_id] ||= []

      pairs.each do |pair|
        read = pair[0]
        pair_read_id = pair[1]
        rev_read = neighbour_node.short_reads.get_read_by_id(pair_read_id)
        if rev_read.nil?
          raise "unexpectedly didn't find read attached to node when one was expected: #{pair_read_id}"
        end
        node_ids_to_read_and_pair[neighbour_node_id] << [read, rev_read]
      end
    end

    # Collate each list of reads into a list of PairedNeighbour objects
    neighbours = []
    node_ids_to_read_and_pair.each do |neighbour_node_id, read_pairs|
      next if neighbour_node_id == oriented_node.node.node_id #nodes paired to themselves don't count

      neighbour = Neighbour.new
      neighbour.connection_type = Neighbour::PAIRED_END_CONNECTION
      neighbour.node = @finishm_graph.graph.nodes[neighbour_node_id]
      log.debug "Setting neighbour node as #{neighbour.node}" if log.debug?

      # find the expected direction of the
      direction_vote = {}
      read_pairs.each do |pair|
        key = pair[1].direction
        direction_vote[key] ||= 0
        direction_vote[key] += 1
      end
      found_direction = direction_vote.max{|a,b| a[1] <=> b[1]}[0]
      if found_direction == true
        neighbour.first_side = Bio::Velvet::Graph::OrientedNodeTrail::END_IS_FIRST
      elsif found_direction == false
        neighbour.first_side = Bio::Velvet::Graph::OrientedNodeTrail::START_IS_FIRST
      end

      distance_sum = 0
      num_adjoining_reads = 0
      read_pairs.each do |pair|
        if found_direction == pair[1].direction
          distance = estimate_distance_between_nodes(oriented_node.node, neighbour.node, pair[0], pair[1], @insert_size)
          unless distance.nil?
            log.debug "Accepting distance #{distance} from read_id #{pair[1].read_id}" if log.debug?
            distance_sum += distance
            num_adjoining_reads += 1
          end
        end
      end

      # don't accept when no adjoining reads are found
      if num_adjoining_reads > 0 and
        (@min_adjoining_reads.nil? or num_adjoining_reads >= @min_adjoining_reads)

        if distance_sum < 0
          # don't predict negative distances
          neighbour.distance = 0
        else
          neighbour.distance = distance_sum.to_f / num_adjoining_reads
        end

        neighbour.num_adjoining_reads = num_adjoining_reads
        neighbours.push neighbour
      end
    end

    return neighbours
  end

  # estimate the distance between the two nodes, assuming that the pair orientation is
  # not problematic. Return nil if the estimated insert size is greater than 2 times the
  # expected insert size, or less than -1 times the insert size.
  def estimate_distance_between_nodes(node1, node2, fwd_read, rev_read, insert_size)
    fwd_contribution = node1.length_alone - fwd_read.offset_from_start_of_node + fwd_read.start_coord
    rev_contribution = node2.length_alone - rev_read.offset_from_start_of_node + rev_read.start_coord
    diff = insert_size - fwd_contribution - rev_contribution
    if diff > insert_size*2 or diff < -insert_size
      return nil
    else
      return diff
    end
  end

  class Neighbour < Bio::Velvet::Graph::OrientedNodeTrail::OrientedNode
    PAIRED_END_CONNECTION = :paired_end_connection
    DIRECT_CONNECTION = :direct_connection
    attr_accessor :connection_type

    attr_accessor :node
    attr_accessor :first_side
    attr_accessor :distance
    attr_accessor :num_adjoining_reads

    def to_settable
      [@node.node_id, @first_side]
    end

    def inspect
      "Neighbour #{object_id}: node=#{@node.node_id} first=#{@first_side} distance=#{@distance} num_adjoining_reads=#{@num_adjoining_reads} connection_type:#{@connection_type}"
    end
    alias_method :to_s, :inspect
  end
end
