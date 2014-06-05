require 'ds'
require 'set'

module Bio
  module AssemblyGraphAlgorithms

    # Represents a set of trails, and whether or not circularity has been detected.
    class TrailSet
      attr_accessor :trails
      attr_accessor :circular_paths_detected
      include Enumerable

      def each
        @trails.each{|t| yield t}
      end
    end

    class AcyclicConnectionFinder
      include Bio::FinishM::Logging

      # Find trails between two oriented nodes, both facing the same way along the path.
      #
      # Options:
      # * :recoherence_kmer: use a longer kmer to help de-bubble and de-cicularise (default don't use this)
      # * :sequences: Bio::Velvet::Sequence object holding sequences of nodes within leash length
      def find_trails_between_nodes(graph, initial_oriented_node, terminal_oriented_node, leash_length, options={})

        #TODO: this is now implemented in the finishm_graph object - just get it from there
        initial_path = Bio::Velvet::Graph::OrientedNodeTrail.new
        initial_path.add_oriented_node initial_oriented_node

        if options[:recoherence_kmer]
          finder = Bio::AssemblyGraphAlgorithms::SingleCoherentPathsBetweenNodesFinder.new
          return finder.find_all_connections_between_two_nodes(
            graph, initial_path, terminal_oriented_node, leash_length, options[:recoherence_kmer], options[:sequences]
            )
        else
          return Bio::AssemblyGraphAlgorithms::PathsBetweenNodesFinder.new.find_all_connections_between_two_nodes(
            graph, initial_path, terminal_oriented_node, leash_length
            )
        end
      end

      # Algorithms like SingleCoherentWanderer#wander give an overly short
      # base pair distance between two probes, because the length of the node
      # containing the probe at either end is not included in the calculation.
      #
      # Return the calibrated distance i.e. the true base pair distance between
      # the start of each node pair. Returned is the given distance plus the
      # distance between the start of each probe and the end of the containing
      # node.
      def calibrate_distance_accounting_for_probes(finishm_graph, probe1_index, probe2_index, distance)
        to_return = distance

        # add the first probe side
        to_return += finishm_graph.probe_node_reads[probe1_index].offset_from_start_of_node
        # add second probe
        to_return += finishm_graph.probe_node_reads[probe2_index].offset_from_start_of_node
        #Hmm, that was easy.
        return to_return
      end
    end
  end
end
